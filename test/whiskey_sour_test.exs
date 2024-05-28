defmodule WhiskeySourTest do
  use ExUnit.Case

  doctest WhiskeySour

  test "greets the world" do
    assert WhiskeySour.hello() == :world
  end
end
