defmodule VideoRoom.ParticipantMapper do
  use GenServer

  alias Membrane.WebRTC.Track

  @type t :: GenServer.sever()

  defmodule Participant do
    @type t :: %__MODULE__{
            mids: [String.t()],
            display_name: String.t()
          }

    @enforce_keys [:mids, :display_name]
    defstruct @enforce_keys

    def to_map(%__MODULE__{mids: mids, display_name: name}),
      do: %{"mids" => mids, "displayName" => name}
  end

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @spec start_link() :: GenServer.on_start()
  def start_link() do
    GenServer.start_link(__MODULE__, %{})
  end

  @spec register_participant(t(), pid(), String.t(), [Track.t()]) :: :ok
  def register_participant(mapper, pid, display_name, tracks) do
    GenServer.call(mapper, {:register_participant, pid, display_name, Enum.map(tracks, & &1.id)})
  end

  @spec list_participants(t()) :: [Participant.t()]
  def list_participants(mapper) do
    GenServer.call(mapper, :list_participants)
  end

  @impl true
  def handle_call({:register_participant, pid, display_name, mids}, _from, state) do
    Process.monitor(pid)
    state = Map.put(state, pid, %Participant{mids: mids, display_name: display_name})

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:list_participants, _from, state) do
    {:reply, state |> Map.values(), state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, Map.delete(state, pid)}
  end
end
