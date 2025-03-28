defmodule Solid.Tags.InlineCommenTagTest do
  use ExUnit.Case, async: true
  alias Solid.{Lexer, ParserContext}
  alias Solid.Tags.InlineCommentTag
  alias Solid.Parser.Loc

  defp parse(template) do
    context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

    with {:ok, "#", context} <- Lexer.tokenize_tag_start(context) do
      InlineCommentTag.parse("#", %Loc{line: 1, column: 1}, context)
    end
  end

  describe "parse/2" do
    test "basic" do
      template = ~s<{% # a comment $ %} {{ yo }}>

      assert parse(template) == {
               :ok,
               %InlineCommentTag{loc: %Loc{column: 1, line: 1}},
               %ParserContext{column: 20, line: 1, mode: :normal, rest: " {{ yo }}"}
             }
    end

    test "empty" do
      template = ~s<{%#%} {{ yo }}>

      assert parse(template) == {
               :ok,
               %Solid.Tags.InlineCommentTag{
                 loc: %Loc{column: 1, line: 1}
               },
               %Solid.ParserContext{
                 column: 6,
                 line: 1,
                 mode: :normal,
                 rest: " {{ yo }}"
               }
             }
    end

    test "multiline" do
      template = """
      {% # a comment

         # another comment

        %}
      {{ yo }}
      """

      assert parse(template) == {
               :ok,
               %Solid.Tags.InlineCommentTag{
                 loc: %Loc{column: 1, line: 1}
               },
               %Solid.ParserContext{
                 column: 5,
                 line: 5,
                 mode: :normal,
                 rest: "\n{{ yo }}\n"
               }
             }
    end

    test "whitespace control" do
      template = """
      {%- # a comment

         # another comment

        -%}
      {{ yo }}
      """

      assert parse(template) == {
               :ok,
               %Solid.Tags.InlineCommentTag{
                 loc: %Loc{column: 1, line: 1}
               },
               %Solid.ParserContext{
                 column: 1,
                 line: 6,
                 mode: :normal,
                 rest: "{{ yo }}\n"
               }
             }
    end
  end

  describe "Renderable impl" do
    test "does nothing" do
      template = ~s<{% # a comment $ %} {{ yo }}>
      context = %Solid.Context{}

      {:ok, tag, _rest} = parse(template)

      assert Solid.Renderable.render(tag, context, []) == {[], %Solid.Context{}}
    end
  end
end
