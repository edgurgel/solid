defmodule Solid.ConditionExpressionTest do
  use ExUnit.Case, async: true

  alias Solid.{BinaryCondition, ConditionExpression, UnaryCondition}

  alias Solid.Parser.Loc

  defp parse(template) do
    context = %Solid.ParserContext{rest: "{{#{template}}}", line: 1, column: 1, mode: :normal}
    {:ok, tokens, _context} = Solid.Lexer.tokenize_object(context)
    ConditionExpression.parse(tokens)
  end

  describe "parse/1" do
    test "expression" do
      template = "var1  and false"

      assert parse(template) == {
               :ok,
               %Solid.UnaryCondition{
                 argument: %Solid.Variable{
                   original_name: "var1",
                   accesses: [],
                   identifier: "var1",
                   loc: %Solid.Parser.Loc{column: 3, line: 1}
                 },
                 argument_filters: [],
                 child_condition: {
                   :and,
                   %Solid.UnaryCondition{
                     argument: %Solid.Literal{
                       loc: %Solid.Parser.Loc{column: 13, line: 1},
                       value: false
                     },
                     argument_filters: [],
                     child_condition: nil,
                     loc: %Solid.Parser.Loc{column: 13, line: 1}
                   }
                 },
                 loc: %Solid.Parser.Loc{column: 3, line: 1}
               }
             }
    end

    test "binary condition with unary child condition" do
      template = "true == 1 and false"

      assert parse(template) == {
               :ok,
               %BinaryCondition{
                 loc: %Loc{column: 3, line: 1},
                 child_condition:
                   {:and,
                    %UnaryCondition{
                      loc: %Loc{column: 17, line: 1},
                      child_condition: nil,
                      argument: %Solid.Literal{
                        loc: %Loc{column: 17, line: 1},
                        value: false
                      },
                      argument_filters: []
                    }},
                 left_argument: %Solid.Literal{
                   loc: %Loc{column: 3, line: 1},
                   value: true
                 },
                 left_argument_filters: [],
                 operator: :==,
                 right_argument: %Solid.Literal{
                   loc: %Loc{column: 11, line: 1},
                   value: 1
                 },
                 right_argument_filters: []
               }
             }
    end

    test "unary condition with binary child condition" do
      template = "true and 1 == false"

      assert parse(template) == {
               :ok,
               %UnaryCondition{
                 loc: %Loc{column: 3, line: 1},
                 argument: %Solid.Literal{
                   loc: %Loc{column: 3, line: 1},
                   value: true
                 },
                 argument_filters: [],
                 child_condition: {
                   :and,
                   %BinaryCondition{
                     child_condition: nil,
                     loc: %Loc{column: 12, line: 1},
                     left_argument: %Solid.Literal{
                       loc: %Loc{column: 12, line: 1},
                       value: 1
                     },
                     left_argument_filters: [],
                     operator: :==,
                     right_argument: %Solid.Literal{
                       loc: %Loc{column: 17, line: 1},
                       value: false
                     },
                     right_argument_filters: []
                   }
                 }
               }
             }
    end

    test "empty tokens" do
      assert parse("") == {:error, "Argument expected", %{line: 1, column: 3}}
    end

    test "wrong condition" do
      assert parse("true an false") == {:error, "Expected Condition", %{column: 8, line: 1}}
    end

    test "unary condition with filter" do
      template = "var1 | size"

      {:ok, condition} = parse(template)

      assert %UnaryCondition{
               argument: %Solid.Variable{identifier: "var1"},
               argument_filters: [%Solid.Filter{function: "size"}]
             } = condition
    end

    test "binary condition with filters on both sides" do
      template = "var1 | upcase == var2 | upcase"

      {:ok, condition} = parse(template)

      assert %BinaryCondition{
               left_argument: %Solid.Variable{identifier: "var1"},
               left_argument_filters: [%Solid.Filter{function: "upcase"}],
               operator: :==,
               right_argument: %Solid.Variable{identifier: "var2"},
               right_argument_filters: [%Solid.Filter{function: "upcase"}]
             } = condition
    end

    test "binary condition with filter with arguments" do
      template = ~s(name | append: " Jr." == "John Jr.")

      {:ok, condition} = parse(template)

      assert %BinaryCondition{
               left_argument: %Solid.Variable{identifier: "name"},
               left_argument_filters: [
                 %Solid.Filter{
                   function: "append",
                   positional_arguments: [%Solid.Literal{value: " Jr."}]
                 }
               ],
               operator: :==,
               right_argument: %Solid.Literal{value: "John Jr."}
             } = condition
    end

    test "condition with filter and child condition" do
      template = "items | size > 0 and active"

      {:ok, condition} = parse(template)

      assert %BinaryCondition{
               left_argument: %Solid.Variable{identifier: "items"},
               left_argument_filters: [%Solid.Filter{function: "size"}],
               operator: :>,
               right_argument: %Solid.Literal{value: 0},
               child_condition:
                 {:and,
                  %UnaryCondition{
                    argument: %Solid.Variable{identifier: "active"}
                  }}
             } = condition
    end
  end

  describe "eval/3" do
    test "execution in the right order" do
      template = "true and false and false or true"
      {:ok, condition} = parse(template)
      context = %Solid.Context{}

      assert ConditionExpression.eval(condition, context, []) == {:ok, false, context}
    end

    test "unary condition with filter" do
      template = "items | size"
      {:ok, condition} = parse(template)
      context = %Solid.Context{vars: %{"items" => [1, 2, 3]}}

      assert {:ok, true, _} = ConditionExpression.eval(condition, context, [])
    end

    test "binary condition with filter comparing size to zero" do
      template = "items | size == 0"
      {:ok, condition} = parse(template)
      context = %Solid.Context{vars: %{"items" => []}}

      assert {:ok, true, _} = ConditionExpression.eval(condition, context, [])
    end

    test "binary condition with filter" do
      template = "name | upcase == \"JOHN\""
      {:ok, condition} = parse(template)
      context = %Solid.Context{vars: %{"name" => "john"}}

      assert {:ok, true, _} = ConditionExpression.eval(condition, context, [])
    end

    test "binary condition with filters on both sides" do
      template = "a | upcase == b | upcase"
      {:ok, condition} = parse(template)
      context = %Solid.Context{vars: %{"a" => "hello", "b" => "Hello"}}

      assert {:ok, true, _} = ConditionExpression.eval(condition, context, [])
    end
  end
end
