defmodule Membrane.Demo.BasicElement.Counter do
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
    mode: :pull,
    demand_unit: :bytes,
    caps: :any,
    options: [
      divisor: [
        type: :integer,
        default: 1,
        description: "Number by which the counter will be divided before sending notification"
      ]
    ]

  def_output_pad :output,
    availability: :always,
    mode: :pull,
    caps: :any

  @impl true
  def handle_init(%__MODULE{interval: interval}) do
    state = %{
      interval: interval,
      counter: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_prepared_to_stopped(_ctx, state) do
    {{:ok, stop_timer: :timer}, %{state | counter: 0}}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    {{:ok, start_timer: {:timer, state.interval}}, state}
  end

  @impl true
  def handle_demand(:output, size, :bytes, _context, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_process(:input, %Membrane.Buffer{} = buffer, _context, state) do
    state = %{state | counter: state.counter + 1}
    {{:ok, buffer: {:output, buffer}}, state}
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

    {{:ok, notify: notification}, new_state}
  end
end
