defmodule Solid.VariableTest do
  use ExUnit.Case, async: true
  alias Solid.Variable
  alias Solid.Parser.Loc

  defp parse(template) do
    context = %Solid.ParserContext{rest: "{{#{template}}}", line: 1, column: 1, mode: :normal}
    {:ok, tokens, _context} = Solid.Lexer.tokenize_object(context)

    Variable.parse(tokens)
  end

  describe "to_string/1" do
    test "variable with accesses" do
      var = %Solid.Variable{
        identifier: "var1",
        original_name: "var1[var2[\"var3\"]][\"var4\"]",
        accesses: [
          %Solid.AccessVariable{
            loc: %Loc{column: 8, line: 1},
            variable: %Solid.Variable{
              original_name: "var2[\"var3\"]",
              loc: %Loc{column: 8, line: 1},
              identifier: "var2",
              accesses: [
                %Solid.AccessLiteral{loc: %Loc{column: 13, line: 1}, value: "var3"}
              ]
            }
          },
          %Solid.AccessLiteral{
            loc: %Loc{column: 19, line: 1},
            value: "var4"
          }
        ],
        loc: %Loc{column: 3, line: 1}
      }

      assert to_string(var) == "var1[var2[\"var3\"]][\"var4\"]"
    end
  end

  describe "parse/1" do
    test "variable" do
      template = "var123 rest"

      assert parse(template) == {
               :ok,
               %Variable{
                 loc: %Loc{column: 3, line: 1},
                 original_name: "var123",
                 accesses: [],
                 identifier: "var123"
               },
               [
                 {:identifier, %{column: 10, line: 1}, "rest"},
                 {:end, %{line: 1, column: 14}}
               ]
             }
    end

    test "bracket variable" do
      template = "['a var'].foo }}"

      assert {
               :ok,
               %Variable{
                 accesses: [
                   %Solid.AccessLiteral{value: "a var"},
                   %Solid.AccessLiteral{value: "foo"}
                 ],
                 identifier: nil,
                 original_name: "['a var'].foo"
               },
               [end: %{column: 17, line: 1}]
             } = parse(template)
    end

    test "variable with accesses" do
      template = ~s{var1.var2["string"][123][var3]}

      assert parse(template) == {
               :ok,
               %Solid.Variable{
                 original_name: "var1.var2[\"string\"][123][var3]",
                 accesses: [
                   %Solid.AccessLiteral{
                     loc: %Loc{column: 8, line: 1},
                     value: "var2"
                   },
                   %Solid.AccessLiteral{
                     loc: %Loc{column: 13, line: 1},
                     value: "string"
                   },
                   %Solid.AccessLiteral{
                     loc: %Loc{column: 23, line: 1},
                     value: 123
                   },
                   %Solid.AccessVariable{
                     loc: %Loc{column: 28, line: 1},
                     variable: %Solid.Variable{
                       loc: %Loc{column: 28, line: 1},
                       original_name: "var3",
                       identifier: "var3",
                       accesses: []
                     }
                   }
                 ],
                 identifier: "var1",
                 loc: %Loc{column: 3, line: 1}
               },
               [end: %{column: 33, line: 1}]
             }
    end

    test "variable with nested accesses" do
      template = "var1[var2.var3].var4"

      assert parse(template) == {
               :ok,
               %Solid.Variable{
                 original_name: "var1[var2.var3].var4",
                 accesses: [
                   %Solid.AccessVariable{
                     loc: %Loc{column: 8, line: 1},
                     variable: %Solid.Variable{
                       original_name: "var2.var3",
                       loc: %Loc{column: 8, line: 1},
                       identifier: "var2",
                       accesses: [
                         %Solid.AccessLiteral{loc: %Loc{column: 13, line: 1}, value: "var3"}
                       ]
                     }
                   },
                   %Solid.AccessLiteral{
                     loc: %Loc{column: 19, line: 1},
                     value: "var4"
                   }
                 ],
                 identifier: "var1",
                 loc: %Loc{column: 3, line: 1}
               },
               [end: %{column: 23, line: 1}]
             }
    end

    test "nil" do
      assert parse("nil") == {
               :ok,
               %Solid.Literal{loc: %Loc{line: 1, column: 3}, value: nil},
               [end: %{line: 1, column: 6}]
             }
    end

    test "empty" do
      assert parse("empty") == {
               :ok,
               %Solid.Literal{loc: %Loc{line: 1, column: 3}, value: %Solid.Literal.Empty{}},
               [end: %{line: 1, column: 8}]
             }
    end

    test "true" do
      assert parse("true") == {
               :ok,
               %Solid.Literal{loc: %Loc{line: 1, column: 3}, value: true},
               [end: %{line: 1, column: 7}]
             }
    end

    test "false" do
      assert parse("false") == {
               :ok,
               %Solid.Literal{loc: %Loc{line: 1, column: 3}, value: false},
               [end: %{line: 1, column: 8}]
             }
    end

    test "blank" do
      assert parse("blank") == {
               :ok,
               %Solid.Literal{loc: %Loc{line: 1, column: 3}, value: ""},
               [end: %{line: 1, column: 8}]
             }
    end

    test "empty tokens" do
      assert parse("") == {:error, "Variable expected", %{line: 1, column: 3}}
    end

    test "broken accesses" do
      template = "var1[var2"

      assert parse(template) == {:error, "Argument access mal terminated", %{column: 12, line: 1}}
    end

    test "broken nested accesses" do
      template = "var1[var2.var3.]"

      assert parse(template) == {:error, "Argument access mal terminated", %{column: 17, line: 1}}
    end
  end
end
