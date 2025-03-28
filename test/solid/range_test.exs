defmodule Solid.RangeTest do
  use ExUnit.Case, async: true

  alias Solid.{ParserContext, Range}
  alias Solid.Parser.Loc

  defp parse(template) do
    context = %ParserContext{rest: "{{#{template}}}", line: 1, column: 1, mode: :normal}
    {:ok, tokens, _context} = Solid.Lexer.tokenize_object(context)
    Range.parse(tokens)
  end

  @loc %Loc{line: 1, column: 1}

  describe "String.Chars impl" do
    test "to_string variables" do
      range = %Range{
        loc: @loc,
        start: %Solid.Variable{
          original_name: "first",
          loc: @loc,
          accesses: [],
          identifier: "first"
        },
        finish: %Solid.Variable{
          original_name: "limit",
          accesses: [],
          identifier: "limit",
          loc: @loc
        }
      }

      assert to_string(range) == "(first..limit)"
    end

    test "to_string literals" do
      range = %Range{
        loc: @loc,
        start: %Solid.Literal{loc: @loc, value: 1},
        finish: %Solid.Literal{value: 2, loc: @loc}
      }

      assert to_string(range) == "(1..2)"
    end
  end

  describe "parse/1" do
    test "range" do
      template = "(first..limit)"

      assert parse(template) == {
               :ok,
               %Solid.Range{
                 finish: %Solid.Variable{
                   original_name: "limit",
                   accesses: [],
                   identifier: "limit",
                   loc: %Loc{column: 11, line: 1}
                 },
                 loc: %Loc{column: 3, line: 1},
                 start: %Solid.Variable{
                   original_name: "first",
                   loc: %Loc{column: 4, line: 1},
                   accesses: [],
                   identifier: "first"
                 }
               },
               [end: %{column: 17, line: 1}]
             }
    end

    test "range literals" do
      template = "(1..5)"

      assert parse(template) == {
               :ok,
               %Solid.Range{
                 finish: %Solid.Literal{
                   loc: %Loc{column: 7, line: 1},
                   value: 5
                 },
                 loc: %Loc{column: 3, line: 1},
                 start: %Solid.Literal{loc: %Loc{column: 4, line: 1}, value: 1}
               },
               [end: %{column: 9, line: 1}]
             }
    end

    test "error" do
      template = "(1..15"

      assert parse(template) == {:error, "Range expected", %{line: 1, column: 3}}
    end
  end
end
