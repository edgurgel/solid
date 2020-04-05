defmodule Solid.ExpressionTest do
  use ExUnit.Case, async: true
  doctest Solid.Expression
  import Solid.Expression

  describe "eval/2" do
    test "expressions with 1 boolean" do
      exps = [{:value, true}]
      assert eval(exps, %{})
    end

    test "expressions 'and' booleans" do
      exps = [{:value, true}, :bool_and, {:value, false}]
      refute eval(exps, %{})
    end

    test "expressions 'or' booleans" do
      exps = [{:value, true}, :bool_or, {:value, false}]
      assert eval(exps, %{})
    end

    test "expressions multiple expressions booleans" do
      exps = [
        {:value, true},
        :bool_and,
        {:value, false},
        :bool_and,
        {:value, false},
        :bool_or,
        {:value, true}
      ]

      refute eval(exps, %{})
    end
  end
end
