defmodule Solid.ContextTest do
  use ExUnit.Case, async: true
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

    test "list access" do
      context = %Context{vars: %{"x" => ["a", "b", "c"]}}
      assert Context.get_in(context, ["x", 1], [:vars]) == "b"
    end

    test "list size" do
      context = %Context{vars: %{"x" => ["a", "b", "c"]}}
      assert Context.get_in(context, ["x", "size"], [:vars]) == 3
    end

    test "map size" do
      context = %Context{vars: %{"x" => %{"a" => 1, "b" => 2}}}
      assert Context.get_in(context, ["x", "size"], [:vars]) == 2
    end

    test "map size key" do
      context = %Context{vars: %{"x" => %{"a" => 1, "b" => 2, "size" => 42}}}
      assert Context.get_in(context, ["x", "size"], [:vars]) == 42
    end
  end

  describe "run_cycle/2" do
    test "first run" do
      cycle = [values: ["one", "two", "three"]]

      context = %Context{cycle_state: %{}}

      new_context = %Context{
        cycle_state: %{
          ["one", "two", "three"] => {0, %{0 => "one", 1 => "two", 2 => "three"}}
        }
      }

      assert Context.run_cycle(context, cycle) == {new_context, "one"}
    end

    test "second run" do
      cycle = [values: ["one", "two", "three"]]

      context = %Context{
        cycle_state: %{
          ["one", "two", "three"] => {0, %{0 => "one", 1 => "two", 2 => "three"}}
        }
      }

      new_context = %Context{
        cycle_state: %{
          ["one", "two", "three"] => {1, %{0 => "one", 1 => "two", 2 => "three"}}
        }
      }

      assert Context.run_cycle(context, cycle) == {new_context, "two"}
    end

    test "third run" do
      cycle = [values: ["one", "two", "three"]]

      context = %Context{
        cycle_state: %{
          ["one", "two", "three"] => {1, %{0 => "one", 1 => "two", 2 => "three"}}
        }
      }

      new_context = %Context{
        cycle_state: %{
          ["one", "two", "three"] => {2, %{0 => "one", 1 => "two", 2 => "three"}}
        }
      }

      assert Context.run_cycle(context, cycle) == {new_context, "three"}
    end

    test "fourth run - loops back" do
      cycle = [values: ["one", "two", "three"]]

      context = %Context{
        cycle_state: %{
          ["one", "two", "three"] => {2, %{0 => "one", 1 => "two", 2 => "three"}}
        }
      }

      new_context = %Context{
        cycle_state: %{
          ["one", "two", "three"] => {0, %{0 => "one", 1 => "two", 2 => "three"}}
        }
      }

      assert Context.run_cycle(context, cycle) == {new_context, "one"}
    end

    test "named first run" do
      cycle = [name: "first", values: ["one", "two", "three"]]

      context = %Context{cycle_state: %{}}

      new_context = %Context{
        cycle_state: %{
          "first" => {0, %{0 => "one", 1 => "two", 2 => "three"}}
        }
      }

      assert Context.run_cycle(context, cycle) == {new_context, "one"}
    end

    test "named second run" do
      cycle = [name: "first", values: ["one", "two", "three"]]

      context = %Context{
        cycle_state: %{
          "first" => {0, %{0 => "one", 1 => "two", 2 => "three"}}
        }
      }

      new_context = %Context{
        cycle_state: %{
          "first" => {1, %{0 => "one", 1 => "two", 2 => "three"}}
        }
      }

      assert Context.run_cycle(context, cycle) == {new_context, "two"}
    end

    test "named third run" do
      cycle = [name: "first", values: ["one", "two", "three"]]

      context = %Context{
        cycle_state: %{
          "first" => {1, %{0 => "one", 1 => "two", 2 => "three"}}
        }
      }

      new_context = %Context{
        cycle_state: %{
          "first" => {2, %{0 => "one", 1 => "two", 2 => "three"}}
        }
      }

      assert Context.run_cycle(context, cycle) == {new_context, "three"}
    end

    test "named fourth run - loops back" do
      cycle = [name: "first", values: ["one", "two", "three"]]

      context = %Context{
        cycle_state: %{
          "first" => {2, %{0 => "one", 1 => "two", 2 => "three"}}
        }
      }

      new_context = %Context{
        cycle_state: %{
          "first" => {0, %{0 => "one", 1 => "two", 2 => "three"}}
        }
      }

      assert Context.run_cycle(context, cycle) == {new_context, "one"}
    end
  end
end
