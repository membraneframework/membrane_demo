defmodule RecordingTest do
  use ExUnit.Case
  doctest Recording

  test "greets the world" do
    assert Recording.hello() == :world
  end
end
