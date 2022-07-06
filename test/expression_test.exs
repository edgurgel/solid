defmodule Solid.ExpressionTest do
  use ExUnit.Case, async: true
  doctest Solid.Expression
  import Solid.Expression
  alias Solid.Context

  describe "eval/2" do
    test "expression with 1 value boolean" do
      context = %Context{}
      exps = [[{:value, true}]]
      assert {true, ^context} = eval(exps, context)
    end

    test "expressions with 1 field boolean" do
      context = %Context{vars: %{"key1" => true}}
      exps = [[{:field, ["key1"]}]]
      assert {true, ^context} = eval(exps, context)
    end

    test "expressions with 1 field boolean strict_variables" do
      context = %Context{}
      exps = [[{:field, ["key1"]}]]
      assert {false, context} = eval(exps, context, strict_variables: true)
      assert context.errors == [%Solid.UndefinedVariableError{variable: ["key1"]}]
    end

    test "expressions 'and' booleans" do
      context = %Context{}
      exps = [[{:value, true}], :bool_and, [{:value, false}]]
      assert {false, ^context} = eval(exps, context)
    end

    test "expressions 'or' booleans" do
      context = %Context{}
      exps = [[{:value, true}], :bool_or, [{:value, false}]]
      assert {true, ^context} = eval(exps, context)
    end

    test "expressions multiple expressions booleans" do
      context = %Context{}

      exps = [
        [argument: [{:value, true}]],
        :bool_and,
        [argument: [{:value, false}]],
        :bool_and,
        [argument: [{:value, false}]],
        :bool_or,
        [argument: [{:value, true}]]
      ]

      assert {false, ^context} = eval(exps, context)
    end
  end
end
