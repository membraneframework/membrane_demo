defmodule Membrane.Demo.VideoMixer do
  @moduledoc """
  Documentation for `VideoMixer`.
  """
  use Membrane.Pipeline

  @impl true
  def handle_init(opts) do
    children = %{}

    # Setup the flow of the data
    links = []

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end
end
