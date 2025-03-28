defmodule Solid.Tags.BreakTagTest do
  use ExUnit.Case, async: true
  alias Solid.Tags.BreakTag
  alias Solid.{Lexer, ParserContext}

  defp parse(template) do
    context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

    with {:ok, "break", context} <- Lexer.tokenize_tag_start(context) do
      BreakTag.parse("break", %{line: 1, column: 1}, context)
    end
  end

  describe "parse/2" do
    test "basic" do
      template = ~s<{% break %}>

      assert parse(template) == {
               :ok,
               %BreakTag{loc: %{column: 1, line: 1}},
               %ParserContext{column: 12, line: 1, mode: :normal, rest: ""}
             }
    end

    test "error" do
      template = ~s<{% break yo %}>
      assert parse(template) == {:error, "Unexpected token", %{column: 10, line: 1}}
    end

    test "unexpected character" do
      template = ~s<{% break - %}>
      assert parse(template) == {:error, "Unexpected character '-'", %{column: 10, line: 1}}
    end
  end

  describe "Renderable impl" do
    test "break exp" do
      template = ~s<{% break %}>
      context = %Solid.Context{}

      {:ok, tag, _rest} = parse(template)

      assert catch_throw(Solid.Renderable.render(tag, context, [])) ==
               {:break_exp, [], context}
    end
  end
end
