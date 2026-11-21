defmodule Solid.InspectTest do
  use ExUnit.Case, async: true
  import Solid.Helpers

  describe "inspect/1" do
    test "maps" do
      assert Solid.Inspect.inspect(%{}) == "{}"
      assert Solid.Inspect.inspect(%{"a" => 1, "b" => "x"}) == ~s({"a"=>1, "b"=>"x"})
      assert Solid.Inspect.inspect(%{"a" => %{"b" => nil}}) == ~s({"a"=>{"b"=>nil}})
    end

    test "lists" do
      assert Solid.Inspect.inspect([]) == "[]"
      assert Solid.Inspect.inspect([1, nil, true, "a", [%{}]]) == ~s([1, nil, true, "a", [{}]])
      assert Solid.Inspect.inspect([104, 105]) == "[104, 105]"
    end

    test "strings are quoted and escaped" do
      assert Solid.Inspect.inspect(["q\"\n"]) == ~S(["q\"\n"])
    end

    test "floats" do
      assert Solid.Inspect.inspect([2.5, 1.0e15, 1.0e-5]) == "[2.5, 1.0e+15, 1.0e-05]"
    end

    test "structs" do
      assert Solid.Inspect.inspect([~D[2024-01-02]]) == "[2024-01-02]"
    end
  end

  describe "rendering" do
    test "outputs maps in Liquid format" do
      assert render("{{ a }}", %{"a" => %{}}) == "{}"
      assert render("{{ a }}", %{"a" => %{"b" => [1, nil]}}) == ~s({"b"=>[1, nil]})
      assert render("{{ a }}", %{"a" => [%{}, %{"b" => 1}]}) == ~s({}{"b"=>1})
    end

    test "filters that take strings use the same format" do
      assert render(~s({{ a | append: "!" }}), %{"a" => %{"b" => 1}}) == ~s({"b"=>1}!)
      assert render(~s({{ a | replace: "{", "<" }}), %{"a" => %{}}) == "<}"
      assert render(~s({{ a | append: "!" }}), %{"a" => [%{}, "x"]}) == ~s([{}, "x"]!)
    end

    test "filters returning maps" do
      data = %{"a" => ["a", "b", %{}]}
      assert render("{{ a | last }}", data) == "{}"
      assert render("{{ a | reverse }}", data) == "{}ba"
      assert render("{{ a | uniq }}", %{"a" => [%{}, %{}, 1]}) == "{}1"
      assert render("{{ a | sort_natural }}", %{"a" => [%{}, 1, "4"]}) == "14{}"
    end
  end
end
