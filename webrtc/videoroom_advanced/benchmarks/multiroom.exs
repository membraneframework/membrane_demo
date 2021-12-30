Code.require_file("./benchmarks/simple_mustang.ex")

defmodule MultiroomScenario do
  @behaviour Beamchmark.Scenario

  @rooms 15
  @peers 4
  # in miliseconds
  @peer_delay 1_000
  # in miliseconds
  @peer_duration 120_000
  @url "http://localhost:4000/?room_id=benchmark"

  @impl true
  def run() do
    for room <- 0..(@rooms - 1), into: [] do
      mustang_options = %{target_url: "#{@url}#{room}", linger: @peer_duration}
      options = %{count: @peers, delay: @peer_delay}
      Task.async(fn -> Stampede.start({SimpleMustang, mustang_options}, options) end)
    end
    |> Task.await_many(:infinity)
  end
end

Beamchmark.run(MultiroomScenario,
  duration: 60,
  delay: 30,
  output_dir: "/tmp/videoroom_benchmark/multiroom"
)
