defmodule Solid.ObjectTest do
  use ExUnit.Case, async: true
  import Solid.Object
  doctest Solid.Object
  alias Solid.Context

  describe "render/2" do
    test "value no filter" do
      assert render([argument: [value: 1]], %Context{}) == "1"
    end

    test "list value no filter" do
      assert render([argument: [value: [1, [2, 3, [4, 5, "six"]]]]], %Context{}) == "12345six"
    end

    test "value with filter" do
      assert render(
               [argument: [value: "a"], filters: [filter: ["upcase", {:arguments, []}]]],
               %Context{}
             ) == "A"
    end

    test "field no filter" do
      context = %Context{vars: %{"var" => 1}}
      assert render([argument: [field: [keys: ["var"], accesses: []]]], context) == "1"
    end

    test "field with filter" do
      context = %Context{vars: %{"var" => "a"}}

      assert render(
               [
                 argument: [field: [keys: ["var"], accesses: []]],
                 filters: [filter: ["upcase", {:arguments, []}]]
               ],
               context
             ) == "A"
    end

    test "field with filter and args" do
      context = %Context{vars: %{"not_var" => "a"}}

      assert render(
               [
                 argument: [field: [keys: ["var"], accesses: []]],
                 filters: [filter: ["default", {:arguments, [value: 1]}]]
               ],
               context
             ) == "1"
    end
  end
end
