defmodule Membrane.Demo.Basic.FirstElement.Element do
  use Membrane.Filter

  def_options interval: [
                type: :integer,
                default: 1000,
                description:
                  "Amount of the time in milliseconds, telling how often statistics should be sent and zeroed"
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
      counter: 0,
      timer: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_prepared_to_stopped(_ctx, state) do
    {:ok, :cancel} = :timer.cancel(state.timer)
    {:ok, %{state | counter: 0, timer: nil}}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, state) do
    {:ok, timer} = :timer.send_interval(state.interval, :tick)
    {:ok, %{state | timer: timer}}
  end

  @impl true
  def handle_demand(:output, size, :bytes, _context, state) do
    {{:ok, demand: {:input, size}}, state}
  end

  @impl true
  def handle_process(:input, %Membrane.Buffer{} = buffer, _context, state) do
    new_state = %{state | counter: state.counter + 1}
    {{:ok, buffer: {:output, buffer}}, new_state}
  end

  @impl true
  def handle_other(:tick, ctx, state) do
    # create the term to send
    notification = {
      :counter,
      div(state.counter, ctx.pads.input.options.divisor)
    }

    # reset the timer
    new_state = %{state | counter: 0}

    {{:ok, notify: notification}, new_state}
  end
end
