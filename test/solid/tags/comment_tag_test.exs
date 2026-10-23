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

  describe "inside a liquid tag" do
    defp render(template) do
      with {:ok, template} <- Solid.parse(template) do
        {:ok, template |> Solid.render!(%{}) |> IO.iodata_to_binary()}
      end
    end

    test "endcomment ends the comment at the start of a line" do
      assert render("{% liquid comment\nendcomment %}after") == {:ok, "after"}
      assert render("{% liquid comment\n  endcomment\necho 1 %}after") == {:ok, "1after"}
    end

    test "endcomment in the middle of a line is part of the comment" do
      template = "{% liquid comment\nfoo endcomment\necho 1\nendcomment %}after"
      assert render(template) == {:ok, "after"}
    end

    test "a line starting with endcomment but naming another tag is part of the comment" do
      assert render("{% liquid comment\nendcommentx\nendcomment %}after") == {:ok, "after"}
    end

    test "endcomment without the end of the liquid tag is an error" do
      assert {:error, %Solid.TemplateError{errors: [error | _]}} =
               render("{% liquid comment\nendcomment")

      assert error.reason == "Comment tag not terminated"
    end

    test "endcomment only in the middle of a line leaves the comment unterminated" do
      assert {:error, %Solid.TemplateError{errors: [error | _]}} =
               render("{% liquid comment\nfoo endcomment %}after")

      assert error.reason == "Comment tag not terminated"
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
