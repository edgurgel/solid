defmodule Solid.Integration.ObjectsTest do
  use ExUnit.Case, async: true
  import Solid.Helpers
  alias Solid.UndefinedVariableError

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

  test "field access by literal string" do
    template = """
    {%- assign greeting = greetings['casual'].text -%}
    <p>{{ greeting }} world</p>
    """

    data = %{
      "greetings" => %{
        "formal" => %{"text" => "Hello"},
        "casual" => %{"text" => "Hey!"},
        "friendly" => %{"text" => "Yo!"}
      }
    }

    assert render(template, data) == """
           <p>Hey! world</p>
           """
  end

  test "field access by variable" do
    template = """
    {%- assign greet_as = 'friendly' -%}
    {%- assign greeting = greetings[greet_as].text -%}
    <p>{{ greeting }} world</p>
    """

    data = %{
      "greetings" => %{
        "formal" => %{"text" => "Hello"},
        "casual" => %{"text" => "Hey!"},
        "friendly" => %{"text" => "Yo!"}
      }
    }

    assert render(template, data) == """
    <p>Yo! world</p>
    """
  end

  test "field access through many variables" do
    template = """
    {%- assign greet_as = 'casual' -%}
    {%- assign really_greet_as = greet_as -%}
    {%- assign really_really_greet_as = really_greet_as -%}
    {%- assign greeting = greetings[really_really_greet_as].text -%}
    <p>{{ greeting }} world</p>
    """

    data = %{
      "greetings" => %{
        "formal" => %{"text" => "Hello"},
        "casual" => %{"text" => "Hey!"},
        "friendly" => %{"text" => "Yo!"}
      }
    }

    assert render(template, data) == """
    <p>Hey! world</p>
    """
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

  test "strict_variables" do
    template = "{{key1}} {{missing1}} {{key2.key3}} {{key2.missing2}}"
    values = %{"key1" => "value1", "key2" => %{"key3" => "value2"}}
    assert {:error, errors, result} = render(template, values, strict_variables: true)

    assert errors == [
             %UndefinedVariableError{variable: ["missing1"]},
             %UndefinedVariableError{variable: ["key2", "missing2"]}
           ]

    assert result == "value1  value2 "
  end
end
