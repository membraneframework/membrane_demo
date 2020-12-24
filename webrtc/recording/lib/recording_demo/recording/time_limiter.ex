defmodule RecordingDemo.Recording.TimeLimiter do
  use Membrane.Filter

  def_input_pad :input, caps: :any, demand_unit: :buffers
  def_output_pad :output, caps: :any

  def_options time_limit: []

  @impl true
  def handle_init(opts) do
    {:ok, Map.from_struct(opts)}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_process(:input, buffer, ctx, state) do
    cond do
      ctx.pads.output.end_of_stream? -> {:ok, state}
      buffer.metadata.timestamp > state.time_limit -> {{:ok, end_of_stream: :output}, state}
      true -> {{:ok, buffer: {:output, buffer}}, state}
    end
  end

  @impl true
  def handle_end_of_stream(:input, ctx, state) do
    if ctx.pads.output.end_of_stream? do
      {:ok, state}
    else
      {{:ok, end_of_stream: :output}, state}
    end
  end
end
