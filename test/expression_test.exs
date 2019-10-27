defmodule Solid.ExpressionTest do
  use ExUnit.Case, async: true
  doctest Solid.Expression
  import Solid.Expression

  describe "eval/2" do
    test "expressions with 1 boolean" do
      exps = [true]
      assert eval(exps, %{})
    end

    test "expressions 'and' booleans" do
      exps = [true, :bool_and, false]
      refute eval(exps, %{})
    end

    test "expressions 'or' booleans" do
      exps = [true, :bool_or, false]
      assert eval(exps, %{})
    end

    test "expressions multiple expressions booleans" do
      exps = [true, :bool_and, false, :bool_and, false, :bool_or, true]
      refute eval(exps, %{})
    end
  end
end
