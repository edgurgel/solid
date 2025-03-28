defmodule Solid.Tags.RawTagTest do
  use ExUnit.Case, async: true
  alias Solid.Tags.RawTag
  alias Solid.{Lexer, ParserContext}
  alias Solid.Parser.Loc

  defp parse(template) do
    context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

    with {:ok, tag_name, context} <- Lexer.tokenize_tag_start(context) do
      RawTag.parse(tag_name, %Loc{line: 1, column: 1}, context)
    end
  end

  describe "parse/2" do
    test "basic" do
      template = ~s<{% raw %} {{ yo }} {% endraw %}>

      assert parse(template) ==
               {
                 :ok,
                 %RawTag{loc: %Loc{line: 1, column: 1}, text: " {{ yo }} "},
                 %Solid.ParserContext{rest: "", line: 1, column: 32, mode: :normal}
               }
    end

    test "basic with whitespace control" do
      template = ~s<{%- raw -%} {{ yo }} {%- endraw -%} >

      assert parse(template) ==
               {
                 :ok,
                 %RawTag{loc: %Loc{column: 1, line: 1}, text: "{{ yo }}"},
                 %Solid.ParserContext{column: 37, line: 1, mode: :normal, rest: ""}
               }
    end

    test "raw tag not closed" do
      template = ~s<{% raw %} {{ yo }} {% end %}>

      assert parse(template) ==
               {:error, "Raw tag not terminated", %{column: 29, line: 1}}
    end

    test "raw tag extra tokens" do
      template = ~s<{% raw arg1 %} {{ yo }} {% endraw %}>

      assert parse(template) == {:error, "Unexpected token", %{column: 8, line: 1}}
    end

    test "raw tag unexpected character" do
      template = ~s<{% raw arg1 - 1 %} {{ yo }} {% endraw %}>

      assert parse(template) == {:error, "Unexpected character '-'", %{column: 13, line: 1}}
    end
  end

  describe "Renderable impl" do
    test "raw tag prints everything inside" do
      template = ~s<{% raw %} {{ yo }} {% endraw %}>
      context = %Solid.Context{}

      {:ok, tag, _rest} = parse(template)

      assert Solid.Renderable.render(tag, context, []) == {" {{ yo }} ", context}
    end
  end
end
