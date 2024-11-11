defmodule BusinessLogicTest do
  use ExUnit.Case
  doctest BusinessLogic

  test "greets the world" do
    assert BusinessLogic.hello() == :world
  end
end
