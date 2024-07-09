defmodule Solid.ContextTest do
  use ExUnit.Case, async: true
  alias Solid.Context

  describe "get_in/3" do
    test "counter_vars scope only" do
      context = %Context{counter_vars: %{"x" => 1}}
      assert Context.get_in(context, ["x"], [:counter_vars]) == {:ok, 1}
    end

    test "vars scope only" do
      context = %Context{vars: %{"x" => 1}}
      assert Context.get_in(context, ["x"], [:vars]) == {:ok, 1}
    end

    test "var scope with false value" do
      context = %Context{vars: %{"x" => false}}
      assert Context.get_in(context, ["x"], [:vars]) == {:ok, false}
    end

    test "var scope with nil value" do
      context = %Context{vars: %{"x" => nil}}
      assert Context.get_in(context, ["x"], [:vars]) == {:ok, nil}
    end

    test "iteration_vars scope only" do
      context = %Context{iteration_vars: %{"x" => 1}}
      assert Context.get_in(context, ["x"], [:iteration_vars]) == {:ok, 1}
    end

    test "nested access" do
      context = %Context{vars: %{"x" => %{"y" => 1}}}
      assert Context.get_in(context, ["x", "y"], [:vars]) == {:ok, 1}
    end

    test "nested access string" do
      context = %Context{vars: %{"x" => "y"}}
      assert Context.get_in(context, ["x", "y"], [:vars]) == {:error, {:not_found, ["x", "y"]}}
    end

    test "nested access nil" do
      context = %Context{vars: %{"x" => 1}}
      assert Context.get_in(context, ["x", "y"], [:vars]) == {:error, {:not_found, ["x", "y"]}}
    end

    test "counter_vars & vars scopes with both keys existing" do
      context = %Context{vars: %{"x" => 1}, counter_vars: %{"x" => 2}}
      assert Context.get_in(context, ["x"], [:vars, :counter_vars]) == {:ok, 1}
    end

    test "counter_vars & vars scopes with counter_vars key existing" do
      context = %Context{counter_vars: %{"x" => 2}}
      assert Context.get_in(context, ["x"], [:vars, :counter_vars]) == {:ok, 2}
    end

    test "list access" do
      context = %Context{vars: %{"x" => ["a", "b", "c"]}}
      assert Context.get_in(context, ["x", 1], [:vars]) == {:ok, "b"}
    end

    test "list size" do
      context = %Context{vars: %{"x" => ["a", "b", "c"]}}
      assert Context.get_in(context, ["x", "size"], [:vars]) == {:ok, 3}
    end

    test "map size" do
      context = %Context{vars: %{"x" => %{"a" => 1, "b" => 2}}}
      assert Context.get_in(context, ["x", "size"], [:vars]) == {:ok, 2}
    end

    test "map size key" do
      context = %Context{vars: %{"x" => %{"a" => 1, "b" => 2, "size" => 42}}}
      assert Context.get_in(context, ["x", "size"], [:vars]) == {:ok, 42}
    end
  end

  defmodule CustomMatcher do
    def match(_, _), do: {:ok, 42}
  end

  describe "get_in/3 with custom matcher module" do
    setup do
      context = %Context{matcher_module: CustomMatcher}
      {:ok, context: context}
    end

    test "counter_vars scope only", %{context: context} do
      context = %{context | counter_vars: %{"x" => 1}}
      assert Context.get_in(context, ["x"], [:counter_vars]) == {:ok, 42}
    end

    test "vars scope only", %{context: context} do
      context = %{context | vars: %{"x" => 1}}
      assert Context.get_in(context, ["x"], [:vars]) == {:ok, 42}
    end

    test "var scope with false value", %{context: context} do
      context = %{context | vars: %{"x" => false}}
      assert Context.get_in(context, ["x"], [:vars]) == {:ok, 42}
    end

    test "var scope with nil value", %{context: context} do
      context = %{context | vars: %{"x" => nil}}
      assert Context.get_in(context, ["x"], [:vars]) == {:ok, 42}
    end

    test "iteration_vars scope only", %{context: context} do
      context = %{context | iteration_vars: %{"x" => 1}}
      assert Context.get_in(context, ["x"], [:iteration_vars]) == {:ok, 42}
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
