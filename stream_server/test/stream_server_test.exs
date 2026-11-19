defmodule StreamServerTest do
  use ExUnit.Case
  doctest StreamServer

  test "greets the world" do
    assert StreamServer.hello() == :world
  end
end
