defmodule Solid.Integration.FiltersTest do
  use ExUnit.Case, async: true
  import Solid.Helpers

  test "multiple filters" do
    assert render("Text {{ key | default: 1 | upcase }} !", %{"key" => "abc"}) == "Text ABC !"
    assert_no_errors!()
  end

  test "upcase filter" do
    assert render("Text {{ key | upcase }} !", %{"key" => "abc"}) == "Text ABC !"
    assert_no_errors!()
  end

  test "default filter with default integer" do
    assert render("Number {{ key | default: 456 }} !") == "Number 456 !"

    assert Solid.ErrorContext.get() == %Solid.ErrorContext{
             errors: [
               %Solid.ErrorContext.UndefinedVariable{variable: "key"}
             ]
           }
  end

  test "default filter with default string" do
    assert render("Number {{ key | default: \"456\" }} !", %{}) == "Number 456 !"

    assert Solid.ErrorContext.get() == %Solid.ErrorContext{
             errors: [
               %Solid.ErrorContext.UndefinedVariable{variable: "key"}
             ]
           }
  end

  test "default filter with default float" do
    assert render("Number {{ key | default: 44.5 }} !", %{}) == "Number 44.5 !"

    assert Solid.ErrorContext.get() == %Solid.ErrorContext{
             errors: [
               %Solid.ErrorContext.UndefinedVariable{variable: "key"}
             ]
           }
  end

  test "default filter with nil" do
    assert render("Number {{ nil | default: 456 }} !", %{"nil" => 123}) == "Number 456 !"
    assert_no_errors!()
  end

  test "default filter with an integer" do
    assert render("Number {{ 123 | default: 456 }} !", %{}) == "Number 123 !"
    assert_no_errors!()
  end

  test "default filter with a negative integer" do
    assert render("Number {{ 123 | plus: -123}} !", %{}) == "Number 0 !"
    assert_no_errors!()
  end

  test "replace" do
    assert render(
             "{{ \"Take my protein pills and put my helmet on\" | replace: \"my\", \"your\" }}",
             %{}
           ) ==
             "Take your protein pills and put your helmet on"

    assert_no_errors!()
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

    assert_no_errors!()
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

  test "blank value after filters applied" do
    assert render("{{ key | upcase }}", %{"key" => ""}) == ""

    assert Solid.ErrorContext.get() == %Solid.ErrorContext{
             errors: [],
             warnings: [
               %Solid.ErrorContext.EmptyWarning{filter: ["upcase"], variable: "key"}
             ]
           }

    assert render("{{ key | upcase | default: '' }}", %{}) == ""

    assert Solid.ErrorContext.get() == %Solid.ErrorContext{
             errors: [
               %Solid.ErrorContext.UndefinedVariable{variable: "key"}
             ],
             warnings: [
               %Solid.ErrorContext.EmptyWarning{filter: ["upcase", "default"], variable: "key"}
             ]
           }
  end
end
