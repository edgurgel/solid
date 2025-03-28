defmodule Solid.Tags.CycleTagTest do
  use ExUnit.Case, async: true

  alias Solid.Tags.CycleTag
  alias Solid.{Lexer, ParserContext}
  alias Solid.Parser.Loc

  defp parse(template) do
    context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

    with {:ok, "cycle", context} <- Lexer.tokenize_tag_start(context) do
      CycleTag.parse("cycle", %Loc{line: 1, column: 1}, context)
    end
  end

  describe "parse/2" do
    test "basic" do
      template = ~s<{% cycle var1, "b", 1 %}>

      assert parse(template) == {
               :ok,
               %CycleTag{
                 name: nil,
                 loc: %Loc{line: 1, column: 1},
                 values: [
                   %Solid.Variable{
                     original_name: "var1",
                     loc: %Loc{column: 10, line: 1},
                     identifier: "var1",
                     accesses: []
                   },
                   %Solid.Literal{loc: %Loc{column: 16, line: 1}, value: "b"},
                   %Solid.Literal{loc: %Loc{column: 21, line: 1}, value: 1}
                 ]
               },
               %ParserContext{rest: "", line: 1, column: 25, mode: :normal}
             }
    end

    test "named" do
      template = ~s<{% cycle "c1": var1, "b", 1 %}>

      assert parse(template) == {
               :ok,
               %CycleTag{
                 loc: %Loc{column: 1, line: 1},
                 name: %Solid.Literal{loc: %Loc{column: 10, line: 1}, value: "c1"},
                 values: [
                   %Solid.Variable{
                     original_name: "var1",
                     loc: %Loc{column: 16, line: 1},
                     identifier: "var1",
                     accesses: []
                   },
                   %Solid.Literal{loc: %Loc{column: 22, line: 1}, value: "b"},
                   %Solid.Literal{loc: %Loc{column: 27, line: 1}, value: 1}
                 ]
               },
               %ParserContext{
                 column: 31,
                 line: 1,
                 mode: :normal,
                 rest: ""
               }
             }
    end

    test "error" do
      template = ~s<{% cycle - %}>

      assert parse(template) == {:error, "Unexpected character '-'", %{line: 1, column: 10}}
    end
  end

  describe "Renderable impl" do
    test "cycle prints" do
      template = ~s<{% cycle "one", "two", "three" %}>
      context = %Solid.Context{}

      {:ok, tag, _rest} = parse(template)

      assert Solid.Renderable.render(tag, context, []) ==
               {
                 ["one"],
                 %Solid.Context{
                   cycle_state: %{
                     "l:one,l:two,l:three" =>
                       {0,
                        %{
                          0 => %Solid.Literal{loc: %Loc{column: 10, line: 1}, value: "one"},
                          1 => %Solid.Literal{loc: %Loc{column: 17, line: 1}, value: "two"},
                          2 => %Solid.Literal{loc: %Loc{column: 24, line: 1}, value: "three"}
                        }}
                   }
                 }
               }
    end
  end
end
