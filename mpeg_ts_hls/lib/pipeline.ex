defmodule HLSPipeline do
  use Membrane.Pipeline

  alias Membrane.HLS.Source
  alias HLS.Playlist.Master

  @impl true
  def handle_init(_ctx, opts) do
    structure =
      child(:source, %Source{reader: %Reader{}, master_playlist_uri: opts[:uri]})

    {[spec: structure], opts}
  end

  @impl true
  def handle_child_notification({:hls_master_playlist, master}, :source, _ctx, state) do
    stream =
      master
      |> Master.variant_streams()
      # we always choose stream variant 0 here
      |> Enum.at(0)

    case stream do
      nil ->
        {[], state}

      stream ->
        structure = [
          get_child(:source)
          |> via_out(Pad.ref(:output, {:rendition, stream}))
          |> child(:sink, Membrane.Debug.Sink)
        ]

        {[{:spec, structure}], state}
    end
  end

  @impl true
  def handle_child_notification(_msg, _child, _ctx, state) do
    {[], state}
  end

  @impl true
  def handle_element_end_of_stream(:sink, :input, _ctx, state) do
    {[terminate: :normal], state}
  end

  @impl true
  def handle_element_end_of_stream(_element, _pad, _ctx, state) do
    {[], state}
  end
end
