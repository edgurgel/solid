defmodule Solid.Tags.EchoTagTest do
  use ExUnit.Case, async: true
  alias Solid.Tags.EchoTag
  alias Solid.{Lexer, ParserContext}
  alias Solid.Parser.Loc

  defp parse(template) do
    context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

    with {:ok, "echo", context} <- Lexer.tokenize_tag_start(context) do
      EchoTag.parse("echo", %Loc{line: 1, column: 1}, context)
    end
  end

  describe "parse/2" do
    test "basic" do
      template = ~s<{% echo "I am a tag" | upcase %}>

      assert parse(template) ==
               {
                 :ok,
                 %EchoTag{
                   loc: %Loc{column: 1, line: 1},
                   object: %Solid.Object{
                     argument: %Solid.Literal{
                       loc: %Solid.Parser.Loc{column: 9, line: 1},
                       value: "I am a tag"
                     },
                     filters: [
                       %Solid.Filter{
                         function: "upcase",
                         loc: %Loc{column: 24, line: 1},
                         named_arguments: %{},
                         positional_arguments: []
                       }
                     ],
                     loc: %Loc{column: 9, line: 1}
                   }
                 },
                 %ParserContext{rest: "", line: 1, column: 33, mode: :normal}
               }
    end

    test "error" do
      template = ~s<{% echo | %}>
      assert parse(template) == {:error, "Argument expected", %{line: 1, column: 9}}
    end

    test "unexpected character" do
      template = ~s<{% echo - %}>
      assert parse(template) == {:error, "Unexpected character '-'", %{column: 9, line: 1}}
    end
  end

  describe "Renderable impl" do
    test "echo prints string" do
      template = ~s<{% echo "I am a tag" | upcase %}>
      context = %Solid.Context{}

      {:ok, tag, _rest} = parse(template)

      assert Solid.Renderable.render(tag, context, []) == {["I AM A TAG"], context}
    end
  end
end
