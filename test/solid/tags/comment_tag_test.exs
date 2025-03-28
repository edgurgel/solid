defmodule Solid.Tags.CommentTagTest do
  use ExUnit.Case, async: true
  alias Solid.Tags.CommentTag
  alias Solid.{Lexer, ParserContext}
  alias Solid.Parser.Loc

  defp parse(template) do
    context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

    with {:ok, "comment", context} <- Lexer.tokenize_tag_start(context) do
      CommentTag.parse("comment", %Loc{line: 1, column: 1}, context)
    end
  end

  describe "parse/2" do
    test "basic" do
      template = ~s<{% comment %} {{ yo }} {% endcomment %}>

      assert parse(template) ==
               {:ok, %CommentTag{loc: %Loc{line: 1, column: 1}},
                %ParserContext{rest: "", line: 1, column: 40, mode: :normal}}
    end

    test "error" do
      template = ~s<{% comment %}>
      assert parse(template) == {:error, "Comment tag not terminated", %{column: 14, line: 1}}
    end
  end

  describe "Renderable impl" do
    test "does nothing" do
      template = ~s<{% comment %} {{ yo }} comment {% endcomment %}>
      context = %Solid.Context{}

      {:ok, tag, _rest} = parse(template)

      assert Solid.Renderable.render(tag, context, []) == {[], %Solid.Context{}}
    end
  end
end
