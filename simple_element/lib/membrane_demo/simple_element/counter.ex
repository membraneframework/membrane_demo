defmodule Membrane.Demo.SimpleElement.Counter do
  @moduledoc """
  Membrane element counting incoming buffers.

  Count of buffers divided by `divisor` (passed via `:input` pad options)
  is sent as a `{:counter, number}` notification once every `interval`
  (passed via element options).
  """
  use Membrane.Filter

  def_options interval: [
                spec: Membrane.Time.non_neg_t(),
                default: 1000,
                description: """
                Amount of the time in milliseconds, telling how often
                the count of buffers should be sent and zeroed.
                """
              ]

  def_input_pad :input,
    availability: :always,
    flow_control: :manual,
    demand_unit: :bytes,
    accepted_format: _any,
    options: [
      divisor: [
        type: :integer,
        default: 1,
        description: "Number by which the counter will be divided before sending notification"
      ]
    ]

  def_output_pad :output,
    availability: :always,
    flow_control: :manual,
    accepted_format: _any

  @impl true
  def handle_init(_ctx, %__MODULE{interval: interval}) do
    state = %{
      interval: interval,
      counter: 0
    }

    {[], state}
  end

  @impl true
  def handle_terminate_request(_ctx, state) do
    {[stop_timer: :timer, terminate: :normal], %{state | counter: 0}}
  end

  @impl true
  def handle_playing(_ctx, state) do
    {[start_timer: {:timer, state.interval}], state}
  end

  @impl true
  def handle_demand(:output, size, :bytes, _context, state) do
    {[demand: {:input, size}], state}
  end

  @impl true
  def handle_buffer(:input, %Membrane.Buffer{} = buffer, _context, state) do
    state = %{state | counter: state.counter + 1}
    {[buffer: {:output, buffer}], state}
  end

  @impl true
  def handle_tick(:timer, ctx, state) do
    # create the term to send
    notification = {
      :counter,
      div(state.counter, ctx.pads.input.options.divisor)
    }

    # reset the counter
    new_state = %{state | counter: 0}

    {[notify_parent: notification], new_state}
  end
end
