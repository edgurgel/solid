defmodule Solid.ObjectTest do
  use ExUnit.Case, async: true
  import Solid.Object
  doctest Solid.Object
  alias Solid.Context

  describe "render/2" do
    test "value no filter" do
      assert render([argument: {:value, 1}], %Context{}) == "1"
    end

    test "value with filter" do
      assert render([argument: {:value, "a"},
                     filters: [{"upcase", []}]], %Context{}) == "A"
    end

    test "field no filter" do
      context = %Context{vars: %{"var" => 1}}
      assert render([argument: {:field, "var"}], context) == "1"
    end

    test "field with filter" do
      context = %Context{vars: %{"var" => "a"}}
      assert render([argument: {:field, "var"},
                     filters: [{"upcase", []}]], context) == "A"
    end
  end
end
