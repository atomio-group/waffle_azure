defmodule WaffleAzureTest do
  use ExUnit.Case
  doctest WaffleAzure

  test "greets the world" do
    assert WaffleAzure.hello() == :world
  end
end
