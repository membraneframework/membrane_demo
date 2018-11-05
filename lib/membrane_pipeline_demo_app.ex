defmodule MembraneMP3Demo.App do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    {:ok, pid} = Membrane.Pipeline.start_link(MembraneMP3Demo.Pipeline, "sample.mp3", [])
    Membrane.Pipeline.play(pid)

    children = []

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end
end
