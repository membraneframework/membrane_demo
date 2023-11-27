defmodule RTSPServer do
  @moduledoc false

  require Membrane.Logger

  @test_ssrc 0xABCDEFFF
  @test_pt 96
  @test_clock_rate 90_000
  @test_udp_port 23_456

  defmodule Pipeline do
    @moduledoc false

    use Membrane.Pipeline

    @impl true
    def handle_init(_ctx, opts) do
      {:ok, address} = String.to_charlist(opts.client_ip) |> :inet.parse_address()

      spec = [
        child(:file_src, %Membrane.File.Source{
          location: opts.fixture_path
        })
        |> child(:parser, %Membrane.H264.Parser{
          generate_best_effort_timestamps: %{
            framerate: opts.framerate
          },
          output_alignment: :nalu,
          repeat_parameter_sets: true,
          skip_until_keyframe: true
        })
        |> via_in(Pad.ref(:input, opts.ssrc), options: [payloader: Membrane.RTP.H264.Payloader])
        |> child(:rtp, Membrane.RTP.SessionBin)
        |> via_out(Pad.ref(:rtp_output, opts.ssrc),
          options: [
            payload_type: opts.pt,
            clock_rate: opts.clock_rate
          ]
        )
        |> child(:realtimer, Membrane.Realtimer)
        |> child(%Membrane.Debug.Filter{
          handle_buffer:
            &Membrane.Logger.warning(
              "buffer123 #{inspect(Membrane.Time.os_time())}: #{inspect(&1)}"
            )
        })
        |> child(:udp_sink, %Membrane.UDP.Sink{
          destination_address: address,
          destination_port_no: opts.client_port,
          local_port_no: opts.server_udp_port
        })
      ]

      {[spec: spec], %{}}
    end

    @impl true
    def handle_element_end_of_stream(:udp_sink, :input, _ctx, state) do
      {[terminate: :normal], state}
    end

    @impl true
    def handle_element_end_of_stream(_child, _pad, _ctx, state) do
      {[], state}
    end
  end

  @spec child_spec(Keyword.t()) :: map()
  def child_spec(args) do
    %{
      id: FakeRTSPserver,
      start: {FakeRTSPserver, :start, [args]}
    }
  end

  @spec start(Keyword.t()) :: any()
  def start(
        ip: ip,
        port: port,
        client_port: client_port,
        parent_pid: parent_pid,
        stream_ctx: stream_ctx
      ) do
    {:ok, spawn_link(fn -> start_server(ip, port, client_port, parent_pid, stream_ctx) end)}
  end

  defp start_server(ip, port, client_port, parent_pid, stream_ctx) do
    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])

    send(parent_pid, :fake_server_ready)
    loop_acceptor(socket, ip, port, client_port, stream_ctx)
  end

  defp loop_acceptor(socket, ip, port, client_port, stream_ctx) do
    {:ok, client} = :gen_tcp.accept(socket)

    state = %{
      ip: ip,
      port: port,
      client_port: client_port,
      cseq: 0,
      server_state: :preinit,
      stream_ctx: stream_ctx
    }

    serve(client, state)
    loop_acceptor(socket, ip, port, client_port, stream_ctx)
  end

  defp serve(socket, state) when state.server_state == :preinit do
    request_type = do_serve(socket, state, [:describe, :get_parameter], [:setup, :play])
    new_state = if request_type == :describe, do: :init, else: :preinit
    serve(socket, %{state | cseq: state.cseq + 1, server_state: new_state})
  end

  defp serve(socket, state) when state.server_state == :init do
    request_type = do_serve(socket, state, [:describe, :get_parameter, :setup], [:play])
    new_state = if request_type == :setup, do: :ready, else: :init
    serve(socket, %{state | cseq: state.cseq + 1, server_state: new_state})
  end

  defp serve(socket, state) when state.server_state == :ready do
    request_type = do_serve(socket, state, [:describe, :get_parameter, :setup, :play])

    new_state =
      if request_type == :play do
        if not is_nil(state.stream_ctx) do
          pipeline_opts = %{
            client_ip: state.ip,
            client_port: state.client_port,
            ssrc: @test_ssrc,
            pt: @test_pt,
            clock_rate: @test_clock_rate,
            server_udp_port: @test_udp_port
          }

          Membrane.Pipeline.start_link(Pipeline, Map.merge(pipeline_opts, state.stream_ctx))
        end

        :playing
      else
        :ready
      end

    serve(socket, %{state | cseq: state.cseq + 1, server_state: new_state})
  end

  defp serve(socket, state) when state.server_state == :playing do
    if is_nil(state.stream_ctx) do
      # For signalling test, don't respond to GET_PARAMETER keep-alives in playing state
      do_serve(socket, state, [:describe, :setup, :play])
    else
      do_serve(socket, state, [:describe, :get_parameter, :setup, :play])
    end

    serve(socket, %{state | cseq: state.cseq + 1})
  end

  defp do_serve(socket, state, respond_on, raise_on \\ []) do
    request = get_request(socket)

    request_type =
      case request do
        "DESCRIBE " <> _rest -> :describe
        "SETUP " <> _rest -> :setup
        "PLAY " <> _rest -> :play
        "GET_PARAMETER " <> _rest -> :get_parameter
        _other -> raise("RTSP Endpoint sent unrecognised request: #{inspect(request)}")
      end

    response_body =
      if Enum.any?(respond_on, fn allowed_request -> request_type == allowed_request end) do
        generate_response(request_type, state)
      end

    if is_nil(response_body) do
      if Enum.any?(raise_on, fn erroneous_request -> request_type == erroneous_request end) do
        raise("""
        RTSP Endpoint sent invalid request: #{inspect(request)}
        to fake server in state: #{inspect(state.server_state)}
        """)
      end
    else
      :gen_tcp.send(socket, "RTSP/1.0 200 OK\r\nCSeq: #{state.cseq}\r\n" <> response_body)
    end

    request_type
  end

  defp get_request(socket, request \\ "") do
    case :gen_tcp.recv(socket, 0) do
      {:ok, packet} ->
        request = request <> packet
        if packet != "\r\n", do: get_request(socket, request), else: request

      {:error, :closed} ->
        exit(:normal)

      {:error, reason} ->
        raise("Error when getting request: #{inspect(reason)}")
    end
  end

  defp generate_response(request_type, state) do
    case request_type do
      :describe ->
        sdp =
          "v=0\r\nm=video 0 RTP/AVP 96\r\na=control:rtsp://#{state.ip}:#{state.port}/control\r\n" <>
            "a=rtpmap:#{@test_pt} H264/#{@test_clock_rate}\r\na=fmtp:#{@test_pt} " <>
            "packetization-mode=1\r\n"

        "Content-Base: rtsp://#{state.ip}:#{state.port}/stream\r\n" <>
          "Content-Type: application/sdp\r\nContent-Length: #{byte_size(sdp)}\r\n\r\n" <> sdp

      :setup ->
        "Transport: RTP/AVP;unicast;client_port=#{state.client_port};" <>
          "server_port=#{@test_udp_port};ssrc=#{Integer.to_string(@test_ssrc, 16)}\r\n\r\n"

      _play_or_get_parameter ->
        "\r\n"
    end
  end
end

server_ip = "127.0.0.1"
rtsp_server_port = 8554
rtp_server_port = 20000
fixture_path = "./assets/video.h264"
fixture_framerate = {60, 1}

{:ok, _pid} =
  RTSPServer.start(
    ip: server_ip,
    port: rtsp_server_port,
    client_port: rtp_server_port,
    parent_pid: self(),
    stream_ctx: %{
      fixture_path: fixture_path,
      framerate: fixture_framerate
    }
  )

Process.sleep(:infinity)
