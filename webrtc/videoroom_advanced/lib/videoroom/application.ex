defmodule VideoRoom.Application do
  @moduledoc false
  use Application

  @cert_file_path "priv/tls_cert.pem"

  @impl true
  def start(_type, _args) do
    config_common_dtls_key_cert()
    create_cert_file()

    children = [
      VideoRoomWeb.Endpoint,
      {Phoenix.PubSub, name: VideoRoom.PubSub},
      {Registry, keys: :unique, name: Videoroom.Room.Registry}
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def stop(_state) do
    delete_cert_file()
    :ok
  end

  @spec get_cert_file_path() :: binary()
  def get_cert_file_path(), do: @cert_file_path

  defp create_cert_file() do
    {:ok, cert} =
      Application.fetch_env!(:membrane_videoroom_demo, :integrated_turn_cert)
      |> File.read()

    {:ok, pkey} =
      Application.fetch_env!(:membrane_videoroom_demo, :integrated_turn_pkey)
      |> File.read()

    File.touch!(@cert_file_path)
    File.chmod!(@cert_file_path, 0o600)
    File.write!(@cert_file_path, "#{cert}\n#{pkey}")
  end

  defp delete_cert_file(), do: File.rm(@cert_file_path)

  defp config_common_dtls_key_cert() do
    {:ok, pid} = ExDTLS.start_link(client_mode: false, dtls_srtp: true)
    {:ok, pkey} = ExDTLS.get_pkey(pid)
    {:ok, cert} = ExDTLS.get_cert(pid)
    :ok = ExDTLS.stop(pid)
    Application.put_env(:membrane_videoroom_demo, :dtls_pkey, pkey)
    Application.put_env(:membrane_videoroom_demo, :dtls_cert, cert)
  end
end
