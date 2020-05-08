defmodule Membrane.Demo.RtpToHls.AAC.Filler do
  # TODO: move to a separate repository
  use Membrane.Filter
  alias Membrane.{Buffer, Time}

  @silent_frame <<222, 2, 0, 76, 97, 118, 99, 53, 56, 46, 53, 52, 46, 49, 48, 48, 0, 2, 48, 64,
                  14>>

  @caps {Membrane.Caps.AAC,
         profile: :LC, samples_per_frame: 1024, sample_rate: 44100, channels: 1}

  def_input_pad :input, demand_unit: :buffers, caps: @caps
  def_output_pad :output, caps: @caps

  def_options init_timestamp: [default: nil]

  @impl true
  def handle_init(opts) do
    {:ok, %{previous_timestamp: opts.init_timestamp, overfill: 0}}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_process(:input, buffer, ctx, state) do
    use Ratio, comparison: true
    %{caps: caps} = ctx.pads.input
    frame_duration = caps.samples_per_frame / caps.sample_rate * Time.second()
    %{timestamp: current_timestamp} = buffer.metadata

    expected_timestamp =
      case state.previous_timestamp do
        nil -> current_timestamp
        _ -> state.previous_timestamp + frame_duration
      end + state.overfill

    {silent_timestamps, maybe_expected_timestamp} =
      Stream.iterate(expected_timestamp, &(&1 + frame_duration))
      |> Enum.take_while(&(&1 - current_timestamp < frame_duration / 2))
      |> Enum.split(-1)

    expected_timestamp =
      case maybe_expected_timestamp do
        [] -> expected_timestamp
        [ts] -> ts
      end

    silent_frames =
      Enum.map(silent_timestamps, fn timestamp ->
        %Buffer{buffer | payload: @silent_frame}
        |> Bunch.Struct.put_in([:metadata, :timestamp], timestamp)
      end)

    state = %{
      state
      | previous_timestamp: current_timestamp,
        overfill: expected_timestamp - current_timestamp
    }

    {{:ok, buffer: {:output, silent_frames ++ [buffer]}}, state}
  end
end
