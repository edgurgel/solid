defmodule Solid.Tags.CounterTagTest do
  use ExUnit.Case, async: true
  alias Solid.Tags.CounterTag
  alias Solid.{Context, Lexer, ParserContext, Renderable}
  alias Solid.Parser.Loc

  defp parse(template) do
    context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

    with {:ok, tag_name, context} <- Lexer.tokenize_tag_start(context) do
      CounterTag.parse(tag_name, %Loc{line: 1, column: 1}, context)
    end
  end

  describe "parse/1" do
    test "increment" do
      template = ~s<{% increment var1 %}>

      assert parse(template) ==
               {
                 :ok,
                 %CounterTag{
                   argument: %Solid.Variable{
                     original_name: "var1",
                     loc: %Loc{column: 14, line: 1},
                     identifier: "var1",
                     accesses: []
                   },
                   loc: %Loc{column: 1, line: 1},
                   operation: :increment
                 },
                 %ParserContext{rest: "", line: 1, column: 21, mode: :normal}
               }
    end

    test "decrement" do
      template = ~s<{% decrement var1 %}>

      assert parse(template) ==
               {
                 :ok,
                 %CounterTag{
                   argument: %Solid.Variable{
                     original_name: "var1",
                     loc: %Loc{column: 14, line: 1},
                     identifier: "var1",
                     accesses: []
                   },
                   loc: %Loc{column: 1, line: 1},
                   operation: :decrement
                 },
                 %ParserContext{rest: "", line: 1, column: 21, mode: :normal}
               }
    end

    test "error missing variable" do
      template = ~s<{% increment %}>
      assert parse(template) == {:error, "Argument expected", %{line: 1, column: 14}}
    end

    test "error extra tokens" do
      template = ~s<{% increment var1 | default: 3 %}>

      assert parse(template) ==
               {:error, "Unexpected token after argument", %{line: 1, column: 19}}
    end
  end

  describe "Renderable impl" do
    test "increment no previous value" do
      template = ~s<{% increment var1 %}>
      context = %Context{}

      {:ok, tag, _rest} = parse(template)

      assert Renderable.render(tag, context, []) ==
               {["0"], %Context{counter_vars: %{"var1" => 1}}}
    end

    test "increment with previous value" do
      template = ~s<{% increment var1 %}>
      context = %Context{counter_vars: %{"var1" => 41}}

      {:ok, tag, _rest} = parse(template)

      assert Renderable.render(tag, context, []) ==
               {["41"], %Context{counter_vars: %{"var1" => 42}}}
    end

    test "decrement no previous value" do
      template = ~s<{% decrement var1 %}>
      context = %Context{}

      {:ok, tag, _rest} = parse(template)

      assert Renderable.render(tag, context, []) ==
               {["-1"], %Context{counter_vars: %{"var1" => -1}}}
    end

    test "decrement with previous value" do
      template = ~s<{% decrement var1 %}>
      context = %Context{counter_vars: %{"var1" => 41}}

      {:ok, tag, _rest} = parse(template)

      assert Renderable.render(tag, context, []) ==
               {["40"], %Context{counter_vars: %{"var1" => 40}}}
    end
  end
end
