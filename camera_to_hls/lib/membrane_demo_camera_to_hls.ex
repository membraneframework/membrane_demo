defmodule Membrane.Demo.CameraToHls do
  @moduledoc """
  This is an entry module for the demo
  which starts the CameraToHls Pipeline
  """

  use Application
  alias Membrane.Demo.CameraToHls.Pipeline

  @impl true
  def start(_type, _args) do
    {:ok, _supervisor, pipeline} = Pipeline.start_link()
    {:ok, pipeline}
  end
end
