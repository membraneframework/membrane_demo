defmodule TestRTCScenario do
  @behaviour Beamchmark.Scenario

  @impl true
  def run() do
    # parse args
    argv = System.argv()

    if length(argv) != 2 do
      raise("""
      No api key or test name. Usage:
      MIX_ENV=benchmark mix run <api_key> <test_name>
      """)
    end

    [api_key, test_name] = argv

    # get specified test and its id
    response = HTTPoison.get!("api.testrtc.com/v1/tests", apikey: api_key)

    test =
      response.body
      |> Poison.decode!()
      |> Enum.filter(fn %{"name" => name} = _test -> name == test_name end)
      |> List.first()

    test_id = Map.get(test, "id")

    # execute test
    HTTPoison.post!("api.testrtc.com/v1/tests/#{test_id}/run", "{}", [
      {"apikey", api_key},
      {"Content-Type", "application/json"}
    ])
  end
end

Beamchmark.run(TestRTCScenario,
  duration: 60,
  delay: 360,
  output_dir: "/tmp/videoroom_benchmark/testRTC"
)
