defmodule Solid.ContextTest do
  use ExUnit.Case
  alias Solid.Context

  describe "get_in/3" do
    test "counter_vars scope only" do
      context = %Context{counter_vars: %{"x" => 1}}
      assert Context.get_in(context, ["x"], [:counter_vars]) == 1
    end

    test "vars scope only" do
      context = %Context{vars: %{"x" => 1}}
      assert Context.get_in(context, ["x"], [:vars]) == 1
    end

    test "iteration_vars scope only" do
      context = %Context{iteration_vars: %{"x" => 1}}
      assert Context.get_in(context, ["x"], [:iteration_vars]) == 1
    end

    test "nested access" do
      context = %Context{vars: %{"x" => %{"y" => 1}}}
      assert Context.get_in(context, ["x", "y"], [:vars]) == 1
    end

    test "nested access string" do
      context = %Context{vars: %{"x" => "y"}}
      assert Context.get_in(context, ["x", "y"], [:vars]) == nil
    end

    test "nested access nil" do
      context = %Context{vars: %{"x" => 1}}
      assert Context.get_in(context, ["x", "y"], [:vars]) == nil
    end

    test "counter_vars & vars scopes with both keys existing" do
      context = %Context{vars: %{"x" => 1}, counter_vars: %{"x" => 2}}
      assert Context.get_in(context, ["x"], [:vars, :counter_vars]) == 1
    end

    test "counter_vars & vars scopes with counter_vars key existing" do
      context = %Context{counter_vars: %{"x" => 2}}
      assert Context.get_in(context, ["x"], [:vars, :counter_vars]) == 2
    end
  end
end
