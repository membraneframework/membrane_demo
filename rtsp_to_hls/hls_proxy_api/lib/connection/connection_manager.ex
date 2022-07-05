defmodule HlsProxyApi.Connection.ConnectionManager do
  @moduledoc false
  use Connection

  require Logger

  alias HlsProxyApi.Connection.{PortAgent, RtspKeepAlive}
  alias HlsProxyApi.Pipelines.RtpToHls
  alias HlsProxyApi.Streams.Stream
  alias Membrane.RTSP

  @delay 15_000

  defmodule ConnectionStatus do
    @moduledoc false
    @type t :: %__MODULE__{
            status: :ok | :not_connected,
            stream: %HlsProxyApi.Streams.Stream{},
            rtsp_session: pid(),
            pipeline: pid(),
            keep_alive: pid(),
            pipeline_options: keyword()
          }

    @enforce_keys [
      :status,
      :stream,
      :pipeline_options
    ]

    defstruct @enforce_keys ++
                [
                  :rtsp_session,
                  :pipeline,
                  :keep_alive
                ]
  end

  @spec start_link(Stream.t()) :: GenServer.on_start()
  def start_link(stream) do
    Logger.debug("ConnectionManager: start_link")

    Connection.start_link(__MODULE__, stream, name: {:via, Registry, {HlsProxyApi.Registry, "ConnectionManager"}})
  end

  @impl true
  def init(%Stream{path: path} = stream) do
    Logger.debug("ConnectionManager: Initializing")
    port = set_port()
    output_path = get_output_path(path)

    {:connect, :init,
     %ConnectionStatus{
       status: :not_connected,
       stream: stream,
       pipeline_options: [
         port: port,
         output_path: output_path
       ]
     }}
  end

  @impl true
  def connect(
        _info,
        %ConnectionStatus{
          pipeline_options: pipeline_options,
          stream: stream
        } = connection_status
      ) do
    stream
    Logger.debug("ConnectionManager: Connecting")

    rtsp_session = start_rtsp_session(connection_status)
    connection_status = %{connection_status | rtsp_session: rtsp_session}

    if is_nil(rtsp_session) do
      {:backoff, @delay, connection_status}
    else
      with {:ok, connection_status} <- get_rtsp_description(connection_status),
           :ok <- setup_rtsp_connection(connection_status),
           :ok <- prepare_directory(pipeline_options[:output_path]),
           {:ok, connection_status} <- start_pipeline(connection_status),
           {:ok, connection_status} <- start_keep_alive(connection_status),
           :ok <- play(connection_status) do
        connection_status = %{connection_status | status: :ok}

        Logger.warn(~s"""
        ConnectionManager processes:
          RTSP session: #{inspect(connection_status.rtsp_session)},
          Membrane Pipeline: #{inspect(connection_status.pipeline)},
          RTSP keep alive: #{inspect(connection_status.keep_alive)}
        """)

        {:ok, connection_status}
      else
        {:error, error_message} ->
          Logger.warn("ConnectionManager: Connection failed: #{inspect(error_message)}")
          {:backoff, @delay, connection_status}
      end
    end
  end

  @impl true
  def disconnect(
        message,
        %ConnectionStatus{
          stream: stream,
          pipeline_options: pipeline_options
        } = connection_status
      ) do
    stream
    Logger.debug("ConnectionManager: Disconnecting: #{message}")

    kill_children(connection_status)

    File.rm_rf(pipeline_options[:output_path])

    connection_status = %{
      connection_status
      | status: :not_connected,
        pipeline: nil,
        rtsp_session: nil,
        keep_alive: nil
    }

    case message do
      :close ->
        PortAgent.remove(pipeline_options[:port])
        {:stop, :shutdown, connection_status}

      :reload ->
        {:connect, :reload, connection_status}

      {:error, error_message} ->
        Logger.error("ConnectionManager: Error: #{inspect(error_message)}")
        {:backoff, @delay, connection_status}
    end
  end

  defp kill_children(%ConnectionStatus{
          pipeline: pipeline,
          keep_alive: keep_alive,
          rtsp_session: rtsp_session
        }) do
    if !is_nil(pipeline) and Process.alive?(pipeline),
      do: Membrane.Pipeline.terminate(pipeline)

    if !is_nil(keep_alive) and Process.alive?(keep_alive), do: GenServer.stop(keep_alive, :normal)

    if !is_nil(rtsp_session) and Process.alive?(rtsp_session), do: RTSP.close(rtsp_session)
  end

  @impl true
  def handle_call(:close, _from, connection_status) do
    {:disconnect, :close, connection_status}
  end

  @impl true
  def handle_call({:reload, new_connection_status}, _from, connection_status) do
    {:disconnect, :reload, Map.merge(connection_status, new_connection_status)}
  end

  @impl true
  def handle_call(:status, _from, %{status: status} = connection_status) do
    {:reply, status, connection_status}
  end

  @impl true
  def handle_info(
        {:DOWN, _ref, :process, pid, reason},
        %ConnectionStatus{
          rtsp_session: rtsp_session,
          pipeline: pipeline,
          keep_alive: keep_alive
        } = connection_status
      )
      when reason != :normal do
    Logger.warn(
      "ConnectionManager: Received DOWN message from #{
        inspect(pid)
      }"
    )

    Logger.warn(~s"""
    ConnectionManager processes:
      RTSP session: #{inspect(rtsp_session)},
      Membrane Pipeline: #{inspect(pipeline)},
      RTSP keep alive: #{inspect(keep_alive)}
    """)

    case pid do
      ^rtsp_session ->
        Logger.error("ConnectionManager: RTSP session crashed")

      ^pipeline ->
        Logger.error("ConnectionManager: Pipeline crashed")

      ^keep_alive ->
        Logger.error(
          "ConnectionManager: Keep_alive process crashed"
        )

      process ->
        Logger.error(
          "ConnectionManager: #{process} process crashed"
        )
    end

    {:disconnect, :reload, connection_status}
  end

  @impl true
  def handle_info(
        {:DOWN, _ref, :process, _pid, reason},
        connection_status
      )
      when reason == :normal do
    {:noreply, connection_status}
  end

  @impl true
  def handle_info({:EXIT, _from, reason}, connection_status) do
    {:disconnect, {:error, reason}, connection_status}
  end

  defp start_rtsp_session(%ConnectionStatus{
         rtsp_session: rtsp_session,
         stream: %Stream{stream_url: stream_url}
       }) do

    if is_nil(rtsp_session) do
      case RTSP.start(stream_url) do
        {:ok, session} ->
          Process.monitor(session)
          session

        {:error, error} ->
          Logger.warn("ConnectionManager: Starting RTSP session failed - #{inspect(error)}")
          nil
      end
    else
      rtsp_session
    end
  end

  defp get_rtsp_description(%ConnectionStatus{rtsp_session: rtsp_session} = connection_status) do
    Logger.debug("ConnectionManager: Setting up RTSP description")

    case RTSP.describe(rtsp_session) do
      {:ok, %{status: 200, body: %{media: sdp_media}}} ->
        attributes = get_video_attributes(sdp_media)

        get_sps_pps(attributes)
        |> Keyword.put(:control, attributes["control"])
        |> then(
          &{:ok,
           Map.update(connection_status, :pipeline_options, [], fn pipeline_options ->
             Keyword.merge(pipeline_options, &1)
           end)}
        )

      _result ->
        {:error, :getting_rtsp_description_failed}
    end
  end

  defp set_port() do
    [start_range, end_range] =
      System.get_env("UDP_PORT_RANGE")
      |> String.split("-", parts: 2)
      |> Enum.map(&String.to_integer/1)

    Range.new(start_range, end_range, 2)
    |> Enum.reduce_while(nil, fn port, _acc ->
      case PortAgent.set_port(port) do
        :ok ->
          {:halt, port}

        _error ->
          {:cont, nil}
      end
    end)
  end

  defp setup_rtsp_connection(
         %ConnectionStatus{
           rtsp_session: rtsp_session,
           pipeline_options: pipeline_options
         } = connection_status
       ) do
    Logger.debug("ConnectionManager: Setting up RTSP connection")

    case RTSP.setup(rtsp_session, "/#{pipeline_options[:control]}", [
           {"Transport", "RTP/AVP;unicast;client_port=#{pipeline_options[:port]}"}
         ]) do
      {:ok, %{status: 200}} ->
        :ok

      result ->
        Logger.debug(
          "ConnectionManager: Setting up RTSP connection failed: #{
            inspect(result)
          }"
        )

        {:error, :setting_up_sdp_connection_failed}
    end
  end

  defp get_output_path(hls_path) do
    directory_path = Application.fetch_env!(:hls_proxy_api, :output_dir)
    Path.join(directory_path, hls_path)
  end

  defp prepare_directory(output_path) do
    File.mkdir_p(output_path)
  end

  defp start_pipeline(%ConnectionStatus{pipeline_options: pipeline_options} = connection_status) do
    Logger.debug("ConnectionManager: Starting Pipeline")

    case RtpToHls.start(pipeline_options) do
      {:ok, pipeline} ->
        Process.monitor(pipeline)
        {:ok, %{connection_status | pipeline: pipeline}}

      on_start ->
        Logger.debug("ConnectionManager: Starting Pipeline failed: #{inspect(on_start)}")

        {:error, :starting_pipeline_failed}
    end
  end

  defp play(%ConnectionStatus{rtsp_session: rtsp_session, pipeline: pipeline} = connection_status) do
    Logger.debug("ConnectionManager: Setting RTSP on play mode")

    case RTSP.play(rtsp_session) do
      {:ok, %{status: 200}} ->
        Membrane.Pipeline.play(pipeline)

      _result ->
        {:error, :play_rtsp_failed}
    end
  end

  defp start_keep_alive(
         %ConnectionStatus{rtsp_session: rtsp_session} =
           connection_status
       ) do
    Logger.debug("ConnectionManager: Starting Keep alive process")

    case RtspKeepAlive.start(rtsp_session) do
      {:ok, keep_alive} ->
        Process.monitor(keep_alive)
        {:ok, %{connection_status | keep_alive: keep_alive}}

      _on_start ->
        {:error, :setting_up_keep_alive_failed}
    end
  end

  defp get_sps_pps(%{"fmtp" => fmtp}) do
    [_payload_type, fmtp_attributes_string] = String.split(fmtp, " ", parts: 2)

    fmtp_attributes =
      fmtp_attributes_string
      |> String.split(";")
      |> Enum.map(fn elem ->
        [key, value] = String.trim(elem) |> String.split("=", parts: 2)
        {key, value}
      end)
      |> Enum.into(%{})

    fmtp_attributes["sprop-parameter-sets"]
    |> String.split(",", parts: 2)
    |> Enum.map(fn elem -> <<0, 0, 0, 1>> <> Base.decode64!(elem) end)
    |> then(fn list -> [[:sps, :pps], list] |> List.zip() end)
  end

  defp get_video_attributes(sdp_media) do
    video_protocol = sdp_media |> Enum.find(fn elem -> elem.type == :video end)

    Map.fetch!(video_protocol, :attributes)
    # fixing inconsistency in keys:
    |> Enum.map(fn {key, value} ->
      case is_atom(key) do
        true -> {Atom.to_string(key), value}
        false -> {key, value}
      end
    end)
    |> Enum.into(%{})
  end
end
