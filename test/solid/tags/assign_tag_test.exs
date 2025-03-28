defmodule Solid.Tags.AssignTagTest do
  use ExUnit.Case, async: true
  alias Solid.Tags.AssignTag
  alias Solid.{Lexer, ParserContext}
  alias Solid.Parser.Loc

  defp parse(template) do
    context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

    with {:ok, "assign", context} <- Lexer.tokenize_tag_start(context) do
      AssignTag.parse("assign", %Loc{line: 1, column: 1}, context)
    end
  end

  describe "parse/1" do
    test "basic" do
      template = ~s<{% assign var1 = "123" %}>

      assert parse(template) ==
               {:ok,
                %AssignTag{
                  loc: %Loc{line: 1, column: 1},
                  argument: %Solid.Variable{
                    original_name: "var1",
                    loc: %Loc{column: 11, line: 1},
                    identifier: "var1",
                    accesses: []
                  },
                  object: %Solid.Object{
                    loc: %Loc{column: 18, line: 1},
                    argument: %Solid.Literal{
                      loc: %Loc{column: 18, line: 1},
                      value: "123"
                    },
                    filters: []
                  }
                }, %Solid.ParserContext{rest: "", line: 1, column: 26, mode: :normal}}
    end

    test "with a filter" do
      template = ~s<{% assign var1 = var2 | default: 3 %}>

      assert parse(template) ==
               {
                 :ok,
                 %AssignTag{
                   loc: %Loc{column: 1, line: 1},
                   object: %Solid.Object{
                     argument: %Solid.Variable{
                       original_name: "var2",
                       loc: %Loc{column: 18, line: 1},
                       accesses: [],
                       identifier: "var2"
                     },
                     filters: [
                       %Solid.Filter{
                         loc: %Loc{line: 1, column: 25},
                         function: "default",
                         positional_arguments: [
                           %Solid.Literal{
                             loc: %Loc{column: 34, line: 1},
                             value: 3
                           }
                         ],
                         named_arguments: %{}
                       }
                     ],
                     loc: %Loc{column: 18, line: 1}
                   },
                   argument: %Solid.Variable{
                     original_name: "var1",
                     accesses: [],
                     identifier: "var1",
                     loc: %Loc{column: 11, line: 1}
                   }
                 },
                 %Solid.ParserContext{
                   column: 38,
                   line: 1,
                   mode: :normal,
                   rest: ""
                 }
               }
    end

    test "error missing variable" do
      template = ~s<{% assign %}>
      assert parse(template) == {:error, "Argument expected", %{line: 1, column: 11}}
    end

    test "error extra tokens" do
      template = ~s<{% assign var1 = 123 = %}>
      assert parse(template) == {:error, "Unexpected token", %{line: 1, column: 22}}
    end

    test "error unexpected operator" do
      template = ~s<{% assign x = 1 - 2 %}{{ x }}>

      assert parse(template) == {:error, "Unexpected character '-'", %{line: 1, column: 17}}
    end
  end

  describe "Renderable impl" do
    test "assign assigns" do
      template = ~s<{% assign var1 = "123" %}>
      context = %Solid.Context{}

      {:ok, tag, _rest} = parse(template)

      assert Solid.Renderable.render(tag, context, []) == {
               [],
               %Solid.Context{
                 vars: %{"var1" => "123"}
               }
             }
    end

    test "assign with accesses" do
      template = ~s<{% assign var[1]['abc'] = "123" %}>
      context = %Solid.Context{}

      {:ok, tag, _rest} = parse(template)

      assert Solid.Renderable.render(tag, context, []) == {
               [],
               %Solid.Context{
                 vars: %{"var[1]['abc']" => "123"}
               }
             }
    end
  end
end
