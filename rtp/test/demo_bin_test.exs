defmodule DemoBinTest do
  use ExUnit.Case
  doctest DemoBin

  test "greets the world" do
    assert DemoBin.hello() == :world
  end
end
