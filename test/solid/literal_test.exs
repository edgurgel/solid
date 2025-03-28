defmodule Solid.LiteralTest do
  use ExUnit.Case, async: true

  alias Solid.Literal
  alias Solid.Parser.Loc

  defp parse(template) do
    context = %Solid.ParserContext{rest: "{{#{template}}}", line: 1, column: 1, mode: :normal}
    {:ok, tokens, _context} = Solid.Lexer.tokenize_object(context)
    Literal.parse(tokens)
  end

  describe "parse/1" do
    test "string literal" do
      template = "'a string'"

      assert parse(template) == {
               :ok,
               %Literal{loc: %Loc{column: 3, line: 1}, value: "a string"},
               [{:end, %{line: 1, column: 13}}]
             }
    end

    test "number literal" do
      template = "0"

      assert parse(template) == {
               :ok,
               %Literal{loc: %Loc{column: 3, line: 1}, value: 0},
               [{:end, %{line: 1, column: 4}}]
             }
    end

    test "negative number literal" do
      template = "-3"

      assert parse(template) == {
               :ok,
               %Literal{
                 loc: %Loc{column: 4, line: 1},
                 value: 3
               },
               [end: %{column: 5, line: 1}]
             }
    end

    test "variable" do
      template = "var123 rest"

      assert parse(template) == {:error, "Literal expected", %{line: 1, column: 3}}
    end

    test "empty tokens" do
      assert parse("") == {:error, "Literal expected", %{line: 1, column: 3}}
    end
  end
end
