defmodule Solid.Tags.IfchangedTagTest do
  use ExUnit.Case, async: true
  alias Solid.Tags.IfchangedTag
  alias Solid.{Lexer, ParserContext}
  alias Solid.Parser.Loc

  defp parse(template) do
    context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

    with {:ok, "ifchanged", context} <- Lexer.tokenize_tag_start(context) do
      IfchangedTag.parse("ifchanged", %Loc{line: 1, column: 1}, context)
    end
  end

  defp render(template, vars \\ %{}) do
    {:ok, template} = Solid.parse(template)
    {:ok, result, []} = Solid.render(template, vars)
    IO.iodata_to_binary(result)
  end

  describe "parse/2" do
    test "basic" do
      template = ~s<{% ifchanged %}{{ yo }}{% endifchanged %}>

      assert parse(template) ==
               {:ok,
                %IfchangedTag{
                  loc: %Loc{line: 1, column: 1},
                  body: [
                    %Solid.Object{
                      loc: %Loc{column: 19, line: 1},
                      argument: %Solid.Variable{
                        original_name: "yo",
                        loc: %Loc{column: 19, line: 1},
                        identifier: "yo",
                        accesses: []
                      },
                      filters: []
                    }
                  ],
                  blank: false
                }, %ParserContext{rest: "", line: 1, column: 42, mode: :normal}}
    end

    test "blank body keeps its whitespace" do
      template = ~s<{% ifchanged %} {% assign a = 1 %} {% endifchanged %}>

      assert {:ok, %IfchangedTag{blank: true, body: [%Solid.Text{text: " "}, _, %Solid.Text{}]},
              _} = parse(template)
    end

    test "arguments are an error" do
      template = ~s<{% ifchanged foo %}x{% endifchanged %}>
      assert parse(template) == {:error, "Unexpected token", %{column: 14, line: 1}}
    end

    test "missing endifchanged" do
      template = ~s<{% ifchanged %}x>
      assert parse(template) == {:error, "Expected 'endifchanged'", %{column: 17, line: 1}}
    end

    test "nested liquid tag must close on the same line" do
      template = ~s<{% liquid liquid ifchanged %}>
      assert {:error, %Solid.TemplateError{}} = Solid.parse(template)
    end
  end

  describe "Renderable impl" do
    test "writes the body when nothing was rendered before" do
      assert render(~s<{% ifchanged %}hello{% endifchanged %}>) == "hello"
    end

    test "empty output is written once" do
      assert render(~s<{% ifchanged %}{% endifchanged %}>) == ""

      assert Solid.Renderable.render(
               %IfchangedTag{loc: %Loc{line: 1, column: 1}, body: []},
               %Solid.Context{},
               []
             ) == {[""], %Solid.Context{registers: %{ifchanged: ""}}}
    end

    test "skips output equal to the previous ifchanged output" do
      template = ~s<{% for i in list %}{% ifchanged %}{{ i }}{% endifchanged %}{% endfor %}>
      assert render(template, %{"list" => [1, 1, 2, 2, 1]}) == "121"
    end

    test "all ifchanged tags share the previous output" do
      template =
        ~s<{% ifchanged %}a{% endifchanged %}{% ifchanged %}b{% endifchanged %}{% ifchanged %}b{% endifchanged %}>

      assert render(template) == "ab"
    end

    test "compares output, not the body" do
      template = """
      {%- assign foo = 'hello' -%}
      {%- ifchanged %}{{ foo }}{% endifchanged -%}
      {%- ifchanged %}{{ foo }}{% endifchanged -%}
      {%- assign foo = 'goodbye' -%}
      {%- ifchanged %}{{ foo }}{% endifchanged -%}
      """

      assert render(template) == "hellogoodbye"
    end

    test "break compares the output rendered before it" do
      template =
        ~s<{% for i in (1..4) %}{% ifchanged %}a{% if i == 2 %}{% break %}{% endif %}b{% endifchanged %}{% endfor %}>

      assert render(template) == "aba"
    end

    test "continue compares the output rendered before it" do
      template =
        ~s|{% for i in (1..4) %}{% ifchanged %}c{% if i > 1 %}{% continue %}{% endif %}d{% endifchanged %}{% endfor %}|

      assert render(template) == "cdc"
    end
  end
end
