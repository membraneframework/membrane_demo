require Logger
Logger.configure(level: :info)

Mix.install([
  {:membrane_core, "~> 1.0"},
  {:membrane_hackney_plugin, "~> 0.11.0"},
  {:membrane_realtimer_plugin, "~> 0.9.0"},
  {:membrane_h26x_plugin, "~> 0.10.0"},
  {:membrane_aac_plugin, "~> 0.18.1"},
  {:membrane_funnel_plugin, "~> 0.9.0"},
  {:membrane_mp4_plugin, "~> 0.34.1"},
  {:membrane_udp_plugin, "~> 0.13.0"},
  {:membrane_rtp_plugin, "~> 0.27.1"},
  {:membrane_rtp_aac_plugin, "~> 0.9.0"},
  {:membrane_rtp_h264_plugin, "~> 0.19.1"}
])

defmodule SendRTP do
  use Membrane.Pipeline

  @samples_url "https://raw.githubusercontent.com/membraneframework/static/gh-pages/samples/big-buck-bunny/"

  @mp4_url @samples_url <> "bun33s.mp4"

  @impl true
  def handle_init(_ctx, _opts) do
    spec =
      child(:video_src, %Membrane.Hackney.Source{
        location: @mp4_url,
        hackney_opts: [follow_redirect: true]
      })
      |> child(:mp4, Membrane.MP4.Demuxer.ISOM)

    {[spec: spec], %{}}
  end

  @impl true
  def handle_child_notification({:new_tracks, tracks}, :mp4, _ctx, state) do
    audio_ssrc = 1234
    video_ssrc = 1235
    {audio_id, _format} = Enum.find(tracks, fn {_id, %format{}} -> format == Membrane.AAC end)
    {video_id, _format} = Enum.find(tracks, fn {_id, %format{}} -> format == Membrane.H264 end)

    spec = [
      get_child(:mp4)
      |> via_out(Pad.ref(:output, video_id))
      |> child(:video_parser, %Membrane.H264.Parser{
        output_stream_structure: :annexb,
        output_alignment: :nalu
      })
      |> child(:video_realtimer, Membrane.Realtimer)
      |> via_in(Pad.ref(:input, video_ssrc),
        options: [payloader: Membrane.RTP.H264.Payloader]
      )
      |> child(:rtp, Membrane.RTP.SessionBin)
      |> via_out(Pad.ref(:rtp_output, video_ssrc), options: [encoding: :H264])
      |> get_child(:funnel),
      get_child(:mp4)
      |> via_out(Pad.ref(:output, audio_id))
      |> child(:audio_realtimer, Membrane.Realtimer)
      |> child(:audio_parser, %Membrane.AAC.Parser{out_encapsulation: :none})
      |> via_in(Pad.ref(:input, audio_ssrc),
        options: [payloader: %Membrane.RTP.AAC.Payloader{frames_per_packet: 1, mode: :hbr}]
      )
      |> get_child(:rtp)
      |> via_out(Pad.ref(:rtp_output, audio_ssrc), options: [encoding: :AAC])
      |> get_child(:funnel),
      child(:funnel, Membrane.Funnel)
      |> child(:udp, %Membrane.UDP.Sink{
        destination_port_no: 5000,
        destination_address: {127, 0, 0, 1}
      })
    ]

    {[spec: spec], state}
  end

  @impl true
  def handle_child_notification(_notification, _child, _ctx, state) do
    {[], state}
  end

  @impl true
  def handle_element_end_of_stream(:udp, :input, _ctx, state) do
    {[terminate: :normal], state}
  end

  @impl true
  def handle_element_end_of_stream(_element, _pad, _ctx, state) do
    {[], state}
  end
end

{:ok, supervisor, _pipeline} = Membrane.Pipeline.start_link(SendRTP)

monitor = Process.monitor(supervisor)

receive do
  {:DOWN, ^monitor, _kind, _pid, :normal} -> :ok
end
