defmodule Membrane.Demo.FirstElement.Element do
  use Membrane.Element.Base.Filter

  def_options(
    interval: [
      type: :integer,
      default: 1000,
      description:
        "Amount of the time in millisecods, telling how often statistics should be sent and zeroed"
    ]
  )

  def_input_pads input: [availability: :always, mode: :pull, demand_unit: :bytes, caps: :any]

  def_output_pads output: [availability: :always, mode: :pull, caps: :any]

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
  def handle_process(:input, %Membrane.Buffer{} = buffer, _, state) do
    new_state = %{state | counter: state.counter + 1}
    {{:ok, buffer: {:output, buffer}}, new_state}
  end

  @impl true
  def handle_other(:tick, _ctx, state) do
    # create structure to send
    notification = {
      :counter,
      state.counter
    }

    # reset the timer
    new_state = %{state | counter: 0}

    {{:ok, notify: notification}, new_state}
  end
end
