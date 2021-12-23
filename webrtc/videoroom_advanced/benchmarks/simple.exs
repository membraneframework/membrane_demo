Code.require_file("./benchmarks/simple_mustang.ex")

defmodule SimpleScenario do
  @behaviour Beamchmark.Scenario

  @peers 4
  # in miliseconds
  @peer_delay 1_000
  # in miliseconds
  @peer_duration 120_000
  @room_url "http://localhost:4000/?room_id=benchmark"

  # stampede or chrome cannot connect more than 16 peers using one instance of browser
  # the problem is probably with granting permissions to mic/cam
  # therefore, we are going to spawn multiple browsers
  @peers_per_browser 4
  # in miliseconds
  @browser_delay 2_000

  @impl true
  def run() do
    if @peers <= 0 or @peers_per_browser <= 0 do
      raise("Bad number of peers or peers per browser. Both of them have to be at least 1.")
    end

    mustang_options = %{target_url: @room_url, linger: @peer_duration}
    options = %{count: @peers_per_browser, delay: @peer_delay}

    browsers = floor(@peers / @peers_per_browser)
    remaining_peers = rem(@peers, @peers_per_browser)

    if browsers < 1 do
      raise("Bad browsers number: #{inspect(browsers)}. It has to be at least 1.")
    end

    for _browser <- 0..(browsers - 1), into: [] do
      task = Task.async(fn -> Stampede.start({SimpleMustang, mustang_options}, options) end)
      Process.sleep(@browser_delay)
      task
    end
    |> then(fn tasks ->
      # if there are any remaining peers create for them separate browser
      if remaining_peers != 0 do
        options = %{options | count: remaining_peers}

        tasks ++
          [Task.async(fn -> Stampede.start({SimpleMustang, mustang_options}, options) end)]
      else
        tasks
      end
    end)
    |> Task.await_many(:infinity)
  end
end

Beamchmark.run(SimpleScenario, duration: 60, delay: 20, output_dir: "/tmp/videoroom_benchmark")
