defmodule CameraToHlsNerves.Pipeline do
  use Membrane.Pipeline

  def start_link(port) do
    Membrane.Pipeline.start_link(__MODULE__, port: port)
  end

  @impl true
  def handle_init(_ctx, opts) do
    Process.sleep(10_000)

    spec = [
      child(:source, Membrane.Rpicam.Source)
      |> child(:parser, Membrane.H264.Parser)
      |> via_in(Pad.ref(:input, :video_track), options: [kind: :video])
      |> child(:webrtc, %Membrane.WebRTC.Sink{
        signaling: {:websocket, port: opts[:port], ip: {0, 0, 0, 0}},
        video_codec: :h264,
        tracks: [:video]
      })
    ]

    {[spec: spec], %{}}
  end
end
