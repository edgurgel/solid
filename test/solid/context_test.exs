defmodule Solid.ContextTest do
  use ExUnit.Case, async: true
  alias Solid.{AccessLiteral, AccessVariable, Context, Literal, Variable}

  @loc %Solid.Parser.Loc{line: 1, column: 1}

  describe "get_in/3" do
    test "counter_vars scope only" do
      var = %Variable{original_name: "x", loc: @loc, identifier: "x", accesses: []}
      context = %Context{counter_vars: %{"x" => 1}}
      assert Context.get_in(context, var, [:counter_vars]) == {:ok, 1, context}
    end

    test "vars scope only" do
      var = %Variable{original_name: "x", loc: @loc, identifier: "x", accesses: []}
      context = %Context{vars: %{"x" => 1}}
      assert Context.get_in(context, var, [:vars]) == {:ok, 1, context}
    end

    test "var scope with false value" do
      var = %Variable{original_name: "x", loc: @loc, identifier: "x", accesses: []}
      context = %Context{vars: %{"x" => false}}
      assert Context.get_in(context, var, [:vars]) == {:ok, false, context}
    end

    test "var scope with nil value" do
      var = %Variable{original_name: "x", loc: @loc, identifier: "x", accesses: []}
      context = %Context{vars: %{"x" => nil}}
      assert Context.get_in(context, var, [:vars]) == {:ok, nil, context}
    end

    test "iteration_vars scope only" do
      var = %Variable{original_name: "x", loc: @loc, identifier: "x", accesses: []}
      context = %Context{iteration_vars: %{"x" => 1}}
      assert Context.get_in(context, var, [:iteration_vars]) == {:ok, 1, context}
    end

    test "nested access" do
      accesses = [%AccessLiteral{loc: @loc, value: "y"}]
      var = %Variable{original_name: "x.y", loc: @loc, identifier: "x", accesses: accesses}
      context = %Context{vars: %{"x" => %{"y" => 1}}}
      assert Context.get_in(context, var, [:vars]) == {:ok, 1, context}
    end

    test "nested access literal not found" do
      accesses = [%AccessLiteral{loc: @loc, value: "y"}]
      var = %Variable{original_name: "x.y", loc: @loc, identifier: "x", accesses: accesses}

      context = %Context{vars: %{"x" => "y"}}
      assert Context.get_in(context, var, [:vars]) == {:error, {:not_found, ["x", "y"]}, context}
    end

    test "nested access variable" do
      accesses = [
        %AccessVariable{
          loc: @loc,
          variable: %Variable{original_name: "y", identifier: "y", loc: @loc, accesses: []}
        }
      ]

      var = %Variable{original_name: "x[y]", loc: @loc, identifier: "x", accesses: accesses}

      context = %Context{vars: %{"y" => "v", "x" => %{"v" => "value"}}}
      assert Context.get_in(context, var, [:vars]) == {:ok, "value", context}
    end

    test "nested access nil" do
      accesses = [%AccessLiteral{loc: @loc, value: "y"}]
      var = %Variable{original_name: "x[\"y\"]", loc: @loc, identifier: "x", accesses: accesses}
      context = %Context{vars: %{"x" => 1}}
      assert Context.get_in(context, var, [:vars]) == {:error, {:not_found, ["x", "y"]}, context}
    end

    test "counter_vars & vars scopes with both keys existing" do
      var = %Variable{original_name: "x", loc: @loc, identifier: "x", accesses: []}
      context = %Context{vars: %{"x" => 1}, counter_vars: %{"x" => 2}}
      assert Context.get_in(context, var, [:vars, :counter_vars]) == {:ok, 1, context}
    end

    test "counter_vars & vars scopes with counter_vars key existing" do
      var = %Variable{original_name: "x", loc: @loc, identifier: "x", accesses: []}
      context = %Context{counter_vars: %{"x" => 2}}
      assert Context.get_in(context, var, [:vars, :counter_vars]) == {:ok, 2, context}
    end

    test "list access" do
      accesses = [%AccessLiteral{loc: @loc, value: 1}]
      var = %Variable{original_name: "x[1]", loc: @loc, identifier: "x", accesses: accesses}
      context = %Context{vars: %{"x" => ["a", "b", "c"]}}
      assert Context.get_in(context, var, [:vars]) == {:ok, "b", context}
    end

    test "list size" do
      accesses = [%AccessLiteral{loc: @loc, value: "size"}]
      var = %Variable{original_name: "x.size", loc: @loc, identifier: "x", accesses: accesses}
      context = %Context{vars: %{"x" => ["a", "b", "c"]}}
      assert Context.get_in(context, var, [:vars]) == {:ok, 3, context}
    end

    test "map size" do
      accesses = [%AccessLiteral{loc: @loc, value: "size"}]
      var = %Variable{original_name: "x.size", loc: @loc, identifier: "x", accesses: accesses}
      context = %Context{vars: %{"x" => %{"a" => 1, "b" => 2}}}
      assert Context.get_in(context, var, [:vars]) == {:ok, 2, context}
    end

    test "map size key" do
      accesses = [%AccessLiteral{loc: @loc, value: "size"}]
      var = %Variable{original_name: "x.size", loc: @loc, identifier: "x", accesses: accesses}
      context = %Context{vars: %{"x" => %{"a" => 1, "b" => 2, "size" => 42}}}
      assert Context.get_in(context, var, [:vars]) == {:ok, 42, context}
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
      var = %Variable{original_name: "x", loc: @loc, identifier: "x", accesses: []}
      context = %{context | counter_vars: %{"x" => 1}}
      assert Context.get_in(context, var, [:counter_vars]) == {:ok, 42, context}
    end

    test "vars scope only", %{context: context} do
      var = %Variable{original_name: "x", loc: @loc, identifier: "x", accesses: []}
      context = %{context | vars: %{"x" => 1}}
      assert Context.get_in(context, var, [:vars]) == {:ok, 42, context}
    end

    test "var scope with false value", %{context: context} do
      var = %Variable{original_name: "x", loc: @loc, identifier: "x", accesses: []}
      context = %{context | vars: %{"x" => false}}
      assert Context.get_in(context, var, [:vars]) == {:ok, 42, context}
    end

    test "var scope with nil value", %{context: context} do
      var = %Variable{original_name: "x", loc: @loc, identifier: "x", accesses: []}
      context = %{context | vars: %{"x" => nil}}
      assert Context.get_in(context, var, [:vars]) == {:ok, 42, context}
    end

    test "iteration_vars scope only", %{context: context} do
      var = %Variable{original_name: "x", loc: @loc, identifier: "x", accesses: []}
      context = %{context | iteration_vars: %{"x" => 1}}
      assert Context.get_in(context, var, [:iteration_vars]) == {:ok, 42, context}
    end
  end

  describe "run_cycle/2" do
    @one %Literal{loc: @loc, value: "one"}
    @two %Literal{loc: @loc, value: "two"}
    @three %Literal{loc: @loc, value: "three"}

    test "first run" do
      values = [@one, @two, @three]

      context = %Context{cycle_state: %{}}

      new_context = %Context{
        cycle_state: %{
          "l:one,l:two,l:three" => {0, %{0 => @one, 1 => @two, 2 => @three}}
        }
      }

      assert Context.run_cycle(context, nil, values) == {new_context, @one}
    end

    test "second run" do
      values = [@one, @two, @three]

      context = %Context{
        cycle_state: %{
          "l:one,l:two,l:three" => {0, %{0 => @one, 1 => @two, 2 => @three}}
        }
      }

      new_context = %Context{
        cycle_state: %{
          "l:one,l:two,l:three" => {1, %{0 => @one, 1 => @two, 2 => @three}}
        }
      }

      assert Context.run_cycle(context, nil, values) == {new_context, @two}
    end

    test "third run" do
      values = [@one, @two, @three]

      context = %Context{
        cycle_state: %{
          "l:one,l:two,l:three" => {1, %{0 => @one, 1 => @two, 2 => @three}}
        }
      }

      new_context = %Context{
        cycle_state: %{
          "l:one,l:two,l:three" => {2, %{0 => @one, 1 => @two, 2 => @three}}
        }
      }

      assert Context.run_cycle(context, nil, values) == {new_context, @three}
    end

    test "fourth run - loops back" do
      values = [@one, @two, @three]

      context = %Context{
        cycle_state: %{
          "l:one,l:two,l:three" => {2, %{0 => @one, 1 => @two, 2 => @three}}
        }
      }

      new_context = %Context{
        cycle_state: %{
          "l:one,l:two,l:three" => {0, %{0 => @one, 1 => @two, 2 => @three}}
        }
      }

      assert Context.run_cycle(context, nil, values) == {new_context, @one}
    end

    test "named first run" do
      name = @one
      values = [@one, @two, @three]

      context = %Context{cycle_state: %{}}

      new_context = %Context{
        cycle_state: %{
          "one" => {0, %{0 => @one, 1 => @two, 2 => @three}}
        }
      }

      assert Context.run_cycle(context, name, values) == {new_context, @one}
    end

    test "named second run" do
      name = @one
      values = [@one, @two, @three]

      context = %Context{
        cycle_state: %{
          "one" => {0, %{0 => @one, 1 => @two, 2 => @three}}
        }
      }

      new_context = %Context{
        cycle_state: %{
          "one" => {1, %{0 => @one, 1 => @two, 2 => @three}}
        }
      }

      assert Context.run_cycle(context, name, values) == {new_context, @two}
    end

    test "named third run" do
      name = @one
      values = [@one, @two, @three]

      context = %Context{
        cycle_state: %{
          "one" => {1, %{0 => @one, 1 => @two, 2 => @three}}
        }
      }

      new_context = %Context{
        cycle_state: %{
          "one" => {2, %{0 => @one, 1 => @two, 2 => @three}}
        }
      }

      assert Context.run_cycle(context, name, values) == {new_context, @three}
    end

    test "named fourth run - loops back" do
      name = @one
      values = [@one, @two, @three]

      context = %Context{
        cycle_state: %{
          "one" => {2, %{0 => @one, 1 => @two, 2 => @three}}
        }
      }

      new_context = %Context{
        cycle_state: %{
          "one" => {0, %{0 => @one, 1 => @two, 2 => @three}}
        }
      }

      assert Context.run_cycle(context, name, values) == {new_context, @one}
    end
  end
end
