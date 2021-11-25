defmodule SimpleMustang do
  use Stampede.Mustang

  @impl true
  def join(browser, options) do
    page = browser |> Playwright.Browser.new_page()
    _response = Playwright.Page.goto(page, options.target_url)

    :ok = Playwright.Page.fill(page, "[name=display_name]", "stampede")
    :ok = Playwright.Page.click(page, "[type=submit]")

    {browser, page}
  end

  @impl true
  def linger({_browser, _page} = ctx, options) do
    Process.sleep(options.linger)
    ctx
  end

  @impl true
  def leave({browser, page}, _options) do
    Playwright.Page.close(page)
    browser
  end
end
