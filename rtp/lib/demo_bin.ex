defmodule Membrane.Demo.RTP do
  @moduledoc """
  This is an entry module for the demo.

  It will accept streams for fmt 96, 127 that should contain multimedia in
  the format of H264 and MPA (respectively)
  as stated in RCSs https://tools.ietf.org/html/rfc6184 and https://tools.ietf.org/html/rfc3551#section-4.5.13 (respectively).
  """
  use Application

  alias Membrane.Demo.RTP.RTPPipeline

  @impl true
  def start(_type, _args) do
    {:ok, pid} = RTPPipeline.start(%{fmt_mapping: %{96 => "H264", 127 => "MPA"}, port: 5000})
    Membrane.Pipeline.play(pid)

    {:ok, pid}
  end
end
