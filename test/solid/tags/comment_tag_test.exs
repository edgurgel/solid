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

    test "endcomment with whitespace control trims what follows" do
      template = "{% comment %} x {% endcomment -%}  \n b"

      assert {:ok, _, %ParserContext{rest: "b", line: 2, column: 2}} = parse(template)
    end

    test "tracks lines and columns across a multi-line body" do
      template = "{% comment %}\n{% comment %}\n{% endcomment %}\n{% endcomment %}after"

      assert {:ok, _, %ParserContext{rest: "after", line: 4, column: 17}} = parse(template)
    end
  end

  defp render(template) do
    with {:ok, template} <- Solid.parse(template) do
      {:ok, template |> Solid.render!(%{}) |> IO.iodata_to_binary()}
    end
  end

  defp first_error(template) do
    assert {:error, %Solid.TemplateError{errors: [error | _]}} = Solid.parse(template)
    error.reason
  end

  describe "nested comments" do
    test "the comment ends at the endcomment that closes the outer comment" do
      assert render("a{% comment %}x{% comment %}y{% endcomment %}z{% endcomment %}b") ==
               {:ok, "ab"}
    end

    test "nested tags inside nested comments are ignored" do
      template = """
      {%- comment %}
        {% if true %}
          {% comment %}
            {% for x in y %}{{ x }}
          {% endcomment %}
        {% endif %}
      {% endcomment -%}
      after\
      """

      assert render(template) == {:ok, "after"}
    end

    test "an unbalanced nested comment is an error" do
      assert first_error("{% comment %}{% comment %}{% endcomment %}") ==
               "Comment tag not terminated"
    end

    test "endcomment followed by more text in the tag name is not an endcomment" do
      assert render("a{% comment %}{% endcommentx %}{% endcomment %}b") == {:ok, "ab"}
    end
  end

  describe "raw inside a comment" do
    test "endcomment inside raw does not end the comment" do
      template = "a{% comment %}{% raw %}{% endcomment %}{% endraw %}{% endcomment %}b"
      assert render(template) == {:ok, "ab"}
    end

    test "a raw block without endraw is an error" do
      assert first_error("{% comment %}    {% raw %} ! {% endcomment %}") ==
               "Raw tag not terminated"
    end

    test "any token ending with endraw closes the raw block" do
      assert render("a{% comment %}{% raw %}{{ {% endraw %}{% endcomment %}b") == {:ok, "ab"}
      assert render("a{% comment %}{% raw %}{% foo {% endraw %}{% endcomment %}b") == {:ok, "ab"}
    end
  end

  describe "incomplete markup inside a comment" do
    test "unclosed output markup swallows the endcomment" do
      assert first_error("{% comment %}{{ {%- endcomment %}") == "Comment tag not terminated"
    end

    test "unclosed tag markup swallows the endcomment" do
      assert first_error("{% comment %}{% assign foo = '1'{% endcomment %}") ==
               "Comment tag not terminated"
    end

    test "unclosed tag markup inside a tag is part of that tag" do
      assert render("a{% comment %}{% foo {% endcomment %}{% endcomment %}b") == {:ok, "ab"}
    end

    test "output markup closed by a single brace" do
      assert render("a{% comment %}{{ x } {% endcomment %}b") == {:ok, "ab"}
    end
  end

  describe "inside a liquid tag" do
    test "nested comments" do
      template = "{% liquid comment\ncomment\nendcomment\nendcomment\necho 1 %}b"
      assert render(template) == {:ok, "1b"}
    end

    test "raw inside a comment can't be closed" do
      assert first_error("{% liquid comment\nraw\nendraw\nendcomment\necho 1 %}b") ==
               "Raw tag not terminated"
    end

    test "the comment can't go past the end of the liquid tag" do
      assert first_error("{% liquid comment\necho 1 -%}  b") == "Comment tag not terminated"
    end

    test "endcomment on the line that closes the liquid tag" do
      assert render("{% liquid comment\nendcomment -%}  b") == {:ok, "b"}
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
