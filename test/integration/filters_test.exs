defmodule Solid.Integration.FiltersTest do
  use ExUnit.Case, async: true
  import Solid.Helpers

  test "multiple filters" do
    assert render("Text {{ key | default: 1 | upcase }} !", %{"key" => "abc"}) == "Text ABC !"
  end

  test "upcase filter" do
    assert render("Text {{ key | upcase }} !", %{"key" => "abc"}) == "Text ABC !"
  end

  test "default filter with default integer" do
    assert render("Number {{ key | default: 456 }} !") == "Number 456 !"
  end

  test "default filter with default string" do
    assert render("Number {{ key | default: \"456\" }} !", %{}) == "Number 456 !"
  end

  test "default filter with default float" do
    assert render("Number {{ key | default: 44.5 }} !", %{}) == "Number 44.5 !"
  end

  test "default filter with nil" do
    assert render("Number {{ nil | default: 456 }} !", %{"nil" => 123}) == "Number 456 !"
  end

  test "default filter with an integer" do
    assert render("Number {{ 123 | default: 456 }} !", %{}) == "Number 123 !"
  end

  test "default filter with a negative integer" do
    assert render("Number {{ 123 | plus: -123}} !", %{}) == "Number 0 !"
  end

  test "replace" do
    assert render(
             "{{ \"Take my protein pills and put my helmet on\" | replace: \"my\", \"your\" }}",
             %{}
           ) ==
             "Take your protein pills and put your helmet on"
  end

  test "concat" do
    assert render(
             """
             {% assign fruits = "apples, oranges" | split: ", " %}
             {% assign vegetables = "kale, cucumbers" | split: ", " %}
             {% assign everything = fruits | concat: vegetables %}
             {% for item in everything %}
             - {{ item }}
             {% endfor %}
             """,
             %{}
           ) == "\n\n\n\n- apples\n\n- oranges\n\n- kale\n\n- cucumbers\n\n"
  end

  test "invalid filter applied" do
    assert render("{{ key | upcase }}", %{"key" => "abc"}) == "ABC"
    assert Solid.ErrorContext.get() == %Solid.ErrorContext{}

    assert render("{{ key | invalid }}", %{"key" => "abc"}) == "abc"

    assert Solid.ErrorContext.get() == %Solid.ErrorContext{
             errors: [
               %Solid.ErrorContext.UndefinedFilter{filter: "invalid"}
             ]
           }

    assert render("{{ key | upcase | invalid | another }}", %{"key" => "abc"}) == "ABC"

    assert Solid.ErrorContext.get() == %Solid.ErrorContext{
             errors: [
               %Solid.ErrorContext.UndefinedFilter{filter: "invalid"},
               %Solid.ErrorContext.UndefinedFilter{filter: "another"}
             ]
           }
  end
end
