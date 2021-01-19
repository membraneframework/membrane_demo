defmodule Membrane.Echo.App do
  @moduledoc false
  use Application

  alias EchoDemo.Router

  @impl true
  def start(_type, _args) do
    config = Application.get_all_env(:echo_demo) |> Map.new()

    children = [
      Plug.Cowboy.child_spec(
        scheme: :https,
        # FIXME: Routers leak - they're spawned on each "/" request and are not terminated
        # can be seen in observer
        plug: Router,
        options: [
          dispatch: dispatch(),
          port: config.port,
          ip: config.ip,
          otp_app: :echo_demo,
          # Attach your SSL certificate and key files here
          keyfile: config.keyfile,
          certfile: config.certfile
        ]
      ),
      %{id: EchoDemo.Echo.Pipeline, start: {EchoDemo.Echo.Pipeline, :start_link, []}}
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end

  defp dispatch do
    [
      {:_,
       [
         {"/ws/echo", EchoDemo.Echo.WS, []},
         {:_, Plug.Cowboy.Handler, {Router, []}}
       ]}
    ]
  end
end
