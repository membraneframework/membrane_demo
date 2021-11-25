defmodule ExampleMustang do
  use Stampede.Mustang

  @impl true
  def join(browser, options) do
    {:ok, page} = browser |> Playwright.Browser.new_page()
    {:ok, _response} =  Playwright.Page.goto(page, options.target_url)

    :ok  = Playwright.Page.fill(page, "[name=display_name]", "stampede")
    Playwright.Page.click(page, "[type=submit]")

    {browser, page}
  end

  @impl true
  def linger({_browser, _page} = ctx, _options) do
    :timer.sleep(:timer.seconds(120))
    ctx
  end

  @impl true
  def leave({browser, page}, _options) do
    #Playwright.Page.click(page, "[id=disconnect]")
    Playwright.Page.close(page)
    browser
  end
end

defmodule SimpleScenario do
  @behaviour Beamchmark.Scenario

  @impl true
  def run() do
    mustang_options = %{target_url: "http://localhost:4000/?room_id=benchmark"}
    options = %{count: 4, delay: 1000}
    Stampede.start({ExampleMustang, mustang_options}, options)
  end
end

Beamchmark.run(SimpleScenario, duration: 60, delay: 20, output_dir: "/tmp/videoroom_benchmark")
