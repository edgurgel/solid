defmodule Solid.ObjectTest do
  use ExUnit.Case, async: true
  import Solid.Object
  doctest Solid.Object
  alias Solid.Context

  describe "render/2" do
    test "value no filter" do
      assert render([argument: [value: 1]], %Context{}, []) == {:ok, "1", %Context{}}
    end

    test "list value no filter" do
      assert render([argument: [value: [1, [2, 3, [4, 5, "six"]]]]], %Context{}, []) ==
               {:ok, "12345six", %Context{}}
    end

    test "map value no filter" do
      assert render([argument: [value: %{"a" => "b"}]], %Context{}, []) ==
               {:ok, "%{\"a\" => \"b\"}", %Context{}}
    end

    test "value with filter" do
      assert render(
               [argument: [value: "a"], filters: [filter: ["upcase", {:arguments, []}]]],
               %Context{},
               []
             ) == {:ok, "A", %Context{}}
    end

    test "field no filter" do
      context = %Context{vars: %{"var" => 1}}
      assert render([argument: [field: ["var"]]], context, []) == {:ok, "1", context}
    end

    test "field with filter" do
      context = %Context{vars: %{"var" => "a"}}

      assert render(
               [argument: [field: ["var"]], filters: [filter: ["upcase", {:arguments, []}]]],
               context,
               []
             ) == {:ok, "A", context}
    end

    test "field with filter and args" do
      context = %Context{vars: %{"not_var" => "a"}}

      assert render(
               [
                 argument: [field: ["var"]],
                 filters: [filter: ["default", {:arguments, [value: 1]}]]
               ],
               context,
               []
             ) == {:ok, "1", context}
    end
  end
end
