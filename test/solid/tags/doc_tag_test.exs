defmodule Solid.Tags.DocTagTest do
  use ExUnit.Case, async: true
  alias Solid.Tags.DocTag
  alias Solid.{Lexer, ParserContext}
  alias Solid.Parser.Loc

  defp parse(template) do
    context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

    with {:ok, "doc", context} <- Lexer.tokenize_tag_start(context) do
      DocTag.parse("doc", %Loc{line: 1, column: 1}, context)
    end
  end

  defp render(template) do
    with {:ok, parsed} <- Solid.parse(template),
         {:ok, iodata, []} <- Solid.render(parsed, %{}) do
      IO.iodata_to_binary(iodata)
    end
  end

  defp parse_errors(template) do
    {:error, %Solid.TemplateError{errors: errors}} = Solid.parse(template)
    Enum.map(errors, &{&1.reason, &1.meta})
  end

  describe "parse/2" do
    test "basic" do
      template = ~s<{% doc %} {{ yo }} {% enddoc %}after>

      assert parse(template) ==
               {:ok, %DocTag{loc: %Loc{line: 1, column: 1}, text: " {{ yo }} "},
                %ParserContext{rest: "after", line: 1, column: 32, mode: :normal}}
    end

    test "keeps the body as written" do
      body = """

        Renders a message.

        @param {string} foo - A string value.
        @param {string} [bar] - An optional string value.

        @example
        {% render 'message', foo: 'Hello', bar: 'World' %}
      """

      assert {:ok, %DocTag{text: ^body}, %ParserContext{rest: ""}} =
               parse("{% doc %}" <> body <> "{% enddoc %}")
    end

    test "whitespace control doesn't trim the body" do
      assert {:ok, %DocTag{text: " a "}, _context} = parse(~s<{% doc -%} a {%- enddoc %}>)
    end

    test "an empty body is blank" do
      assert {:ok, %DocTag{text: ""} = tag, _context} = parse(~s<{% doc %}{% enddoc %}>)
      assert Solid.Block.blank?(tag)

      assert {:ok, %DocTag{text: " "} = tag, _context} = parse(~s<{% doc %} {% enddoc %}>)
      refute Solid.Block.blank?(tag)
    end

    test "the body is not parsed" do
      for body <- ["{{ foo ", "{% assign x = y ", "{% if true %}", "{% endif %}", "{% raw %}"] do
        assert {:ok, %DocTag{text: ^body}, %ParserContext{rest: ""}} =
                 parse("{% doc %}#{body}{% enddoc %}"),
               "body: #{body}"
      end
    end

    test "tracks lines and columns across a multi-line body" do
      template = "{% doc %}\n  @param x\n{% enddoc %}after"

      assert {:ok, _, %ParserContext{rest: "after", line: 3, column: 13}} = parse(template)
    end

    test "enddoc with whitespace control trims what follows" do
      template = "{% doc %} x {% enddoc -%}  \n b"

      assert {:ok, _, %ParserContext{rest: "b", line: 2, column: 2}} = parse(template)
    end

    test "error not terminated" do
      assert parse(~s<{% doc %}hello {% enddocs %}>) ==
               {:error, "Doc tag not terminated", %{line: 1, column: 29}}
    end

    test "error doc arguments" do
      assert parse(~s<{% doc hello %}x{% enddoc %}>) ==
               {:error, "Unexpected token", %{line: 1, column: 8}}
    end

    test "error enddoc arguments" do
      assert parse(~s<{% doc %}x{% enddoc hello %}>) ==
               {:error, "Unexpected token", %{line: 1, column: 21}}
    end

    test "error nested doc" do
      assert parse(~s<{% doc %}x{% doc %}{% enddoc %}>) ==
               {:error, "Nested doc tags are not allowed", %{line: 1, column: 11}}
    end
  end

  describe "in a template" do
    test "renders nothing" do
      assert render("a{% doc %}don't render me{% enddoc %}b") == "ab"
    end

    test "whitespace control" do
      assert render("foo\n {%- doc %}I'm a doc comment{% enddoc -%}  \tbar") == "foobar"
    end

    test "only an empty doc is blank" do
      assert render("[{% if true %} {% doc %}{% enddoc %} {% endif %}]") == "[]"
      assert render("[{% if true %} {% doc %}x{% enddoc %} {% endif %}]") == "[  ]"
    end

    test "error inside a liquid tag" do
      assert [{"The doc tag is not allowed inside a liquid tag", %{line: 1}} | _] =
               parse_errors("{% liquid doc\nenddoc %}")
    end
  end
end
