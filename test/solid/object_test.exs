defmodule Solid.ObjectTest do
  use ExUnit.Case, async: true
  alias Solid.{Lexer, Object, ParserContext}
  alias Solid.Parser.Loc
  alias Solid.Renderable

  defp parse(template) do
    context = %ParserContext{rest: "{{#{template}}}", line: 1, column: 1, mode: :normal}
    {:ok, tokens, _context} = Lexer.tokenize_object(context)
    Object.parse(tokens)
  end

  describe "parse/2" do
    test "empty tokens" do
      assert {:ok, object, [end: %{line: 1, column: 3}]} = parse("")

      assert object == %Object{
               loc: %Loc{column: 3, line: 1},
               argument: %Solid.Literal{loc: %Loc{column: 3, line: 1}, value: nil},
               filters: []
             }
    end

    test "object literal string" do
      assert parse("'a string'") == {
               :ok,
               %Object{
                 loc: %Loc{column: 3, line: 1},
                 argument: %Solid.Literal{
                   loc: %Loc{column: 3, line: 1},
                   value: "a string"
                 },
                 filters: []
               },
               [end: %{line: 1, column: 13}]
             }
    end

    test "bracket variable" do
      template = "['a var'].foo }}"

      assert {
               :ok,
               %Object{
                 argument: %Solid.Variable{
                   identifier: "a var",
                   accesses: [
                     %Solid.AccessLiteral{
                       value: "foo"
                     }
                   ],
                   original_name: "['a var'].foo"
                 },
                 filters: []
               },
               [end: %{line: 1, column: 17}]
             } = parse(template)
    end

    test "broken bracket access" do
      template = "var[] }}"

      assert {:error, "Argument access expected", _meta} = parse(template)
    end

    test "broken dot access" do
      template = "var.  }}"

      assert {:error, "Unexpected token", _meta} = parse(template)
    end

    test "incomplete filter arguments" do
      template = "'a string' | default: }}"

      assert {:error, "Arguments expected", _meta} = parse(template)
    end

    test "missing filter" do
      template = "'a string' | }}"

      assert {:error, "Filter expected", _meta} = parse(template)
    end
  end

  describe "Renderable impl" do
    test "basic var rendering" do
      template = "var1 }}"
      assert {:ok, object, _tokens} = parse(template)

      context = %Solid.Context{vars: %{"var1" => "the value"}}

      assert {"the value", ^context} = Renderable.render(object, context, [])
    end

    test "basic literal rendering" do
      template = "'a string' }}"
      assert {:ok, object, _tokens} = parse(template)

      context = %Solid.Context{}

      assert {"a string", ^context} = Renderable.render(object, context, [])
    end
  end
end
