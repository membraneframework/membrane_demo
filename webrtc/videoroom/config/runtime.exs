import Config

config :membrane_videoroom_demo, VideoRoomWeb.Endpoint, [
  {:url, [host: "localhost"]},
  {:http, [otp_app: :membrane_videoroom_demo, port: System.get_env("SERVER_PORT") || 4000]}
]

# You can also supply opentelemetry resources using environment variables, eg.:
# OTEL_RESOURCE_ATTRIBUTES=service.name=name,service.namespace=namespace

otel_state = :local

config :opentelemetry, :resource,
  service: [
    name: "membrane",
    namespace: "membrane"
  ],
  tracer: :otel_tracer_default

config :opentelemetry, text_map_propagators: [:baggage, :tracer_context]

exporter =
  case otel_state do
    :local ->
      {:otel_exporter_stdout, []}

    :honeycomb ->
      {:opentelemetry_exporter,
       %{
         endpoints: ["https://api.honeycomb.io:443"],
         headers: [
           {"x-honeycomb-dataset", "experiments"},
           {"x-honeycomb-team", System.get_env("HONEYCOMB")}
         ]
       }}

    true ->
      {}
  end

if otel_state != :purge,
  do:
    config(:opentelemetry,
      processors: [
        otel_batch_processor: %{
          exporter: exporter
        }
      ]
    )
