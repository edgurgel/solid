defmodule Solid.Integration.ObjectsTest do
  use ExUnit.Case, async: true
  import Solid.Helpers

  test "no liquid template" do
    assert render("No Number!", %{"key" => 123}) == "No Number!"
  end

  test "single quoted string" do
    assert render("String: {{ 'text' }}") == "String: text"
  end

  test "double quoted string" do
    assert render("String: {{ \"text\" }}") == "String: text"
  end

  test "basic key rendering" do
    assert render("Number {{ key }} ! {{ key }}", %{"key" => 123}) == "Number 123 ! 123"
  end

  test "key rendering with list" do
    assert render("Number {{ key }} ! {{ key }}", %{"key" => [1, [2, "three"]]}) ==
             "Number 12three ! 12three"
  end

  test "field with access" do
    assert render("Number {{ key[1] }}", %{"key" => [1, 2, 3]}) == "Number 2"
  end

  test "complex key rendering" do
    hash = %{"key1" => %{"key2" => %{"key3" => 123}}}
    assert render("Number {{ key1.key2.key3 }} !", hash) == "Number 123 !"
  end

  test "whitespace control" do
    template = """
    Hi

    :
     {{-  name  -}}

    !
    """

    assert render(template, %{"name" => "Hans"}) == """
           Hi

           :Hans!
           """
  end

  test "missing variables" do
    assert render("Number {{ key }}", %{"key" => 1}) == "Number 1"
    assert Solid.ErrorContext.get() == %Solid.ErrorContext{}

    assert render("Number {{ key }} ! {{ key.value }} ! {{list[0]}} {{list[1]}}", %{"list" => [1]}) ==
             "Number  !  ! 1 "

    assert Solid.ErrorContext.get() == %Solid.ErrorContext{
             errors: [
               %Solid.ErrorContext.UndefinedVariable{variable: "key"},
               %Solid.ErrorContext.UndefinedVariable{variable: "key.value"},
               %Solid.ErrorContext.UndefinedVariable{variable: "list.1"}
             ]
           }
  end
end
