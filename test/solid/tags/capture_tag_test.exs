defmodule Solid.Tags.CaptureTagTest do
  use ExUnit.Case, async: true
  alias Solid.Tags.CaptureTag
  alias Solid.{Lexer, ParserContext}
  alias Solid.Parser.Loc

  defp parse(template) do
    context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

    with {:ok, "capture", context} <- Lexer.tokenize_tag_start(context) do
      CaptureTag.parse("capture", %Loc{line: 1, column: 1}, context)
    end
  end

  describe "parse/2" do
    test "basic" do
      template = ~s<{% capture var1 %} {{ yo }} {% endcapture %}>

      assert parse(template) ==
               {:ok,
                %CaptureTag{
                  loc: %Loc{line: 1, column: 1},
                  argument: %Solid.Variable{
                    original_name: "var1",
                    loc: %Loc{column: 12, line: 1},
                    identifier: "var1",
                    accesses: []
                  },
                  body: [
                    %Solid.Text{loc: %Loc{column: 19, line: 1}, text: " "},
                    %Solid.Object{
                      loc: %Loc{column: 23, line: 1},
                      argument: %Solid.Variable{
                        original_name: "yo",
                        loc: %Loc{column: 23, line: 1},
                        identifier: "yo",
                        accesses: []
                      },
                      filters: []
                    },
                    %Solid.Text{loc: %Loc{column: 28, line: 1}, text: " "}
                  ]
                }, %ParserContext{rest: "", line: 1, column: 45, mode: :normal}}
    end

    test "error" do
      template = ~s<{% capture | %}>
      assert parse(template) == {:error, "Argument expected", %{column: 12, line: 1}}
    end

    test "error extra token" do
      template = ~s<{% capture var1 = true %}>
      assert parse(template) == {:error, "Unexpected token", %{column: 17, line: 1}}
    end
  end

  describe "Renderable impl" do
    test "capture captures" do
      template = ~s<{% capture var1 -%} {{ yo }} captured {%- endcapture %}>
      context = %Solid.Context{vars: %{"yo" => "HEY!"}}

      {:ok, tag, _rest} = parse(template)

      assert Solid.Renderable.render(tag, context, []) ==
               {[], %Solid.Context{vars: %{"yo" => "HEY!", "var1" => "HEY! captured"}}}
    end

    test "capture with accesses" do
      template = ~s<{% capture var1[1]['abc'] -%} {{ yo }} captured {%- endcapture %}>
      context = %Solid.Context{vars: %{"yo" => "HEY!"}}

      {:ok, tag, _rest} = parse(template)

      assert Solid.Renderable.render(tag, context, []) ==
               {[],
                %Solid.Context{
                  vars: %{
                    "yo" => "HEY!",
                    "var1[1]['abc']" => "HEY! captured"
                  }
                }}
    end
  end
end
