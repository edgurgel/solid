defmodule Solid.Tags.TablerowTagTest do
  use ExUnit.Case, async: true

  alias Solid.Tags.TablerowTag
  alias Solid.{Lexer, ParserContext}
  alias Solid.Parser.Loc

  defp parse(template) do
    context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

    with {:ok, tag_name, context} <- Lexer.tokenize_tag_start(context) do
      TablerowTag.parse(tag_name, %Loc{line: 1, column: 1}, context)
    end
  end

  describe "parse/2" do
    test "tablerow" do
      template = """
      {% tablerow product in products %}
        {{ product.title }}
      {% endtablerow %}
      """

      assert parse(template) == {
               :ok,
               %TablerowTag{
                 loc: %Loc{line: 1, column: 1},
                 variable: %Solid.Variable{
                   loc: %Loc{line: 1, column: 13},
                   identifier: "product",
                   original_name: "product",
                   accesses: []
                 },
                 body: [
                   %Solid.Text{loc: %Loc{line: 1, column: 35}, text: "\n  "},
                   %Solid.Object{
                     loc: %Loc{line: 2, column: 6},
                     argument: %Solid.Variable{
                       loc: %Loc{line: 2, column: 6},
                       identifier: "product",
                       accesses: [
                         %Solid.AccessLiteral{
                           loc: %Loc{line: 2, column: 14},
                           access_type: :dot,
                           value: "title"
                         }
                       ],
                       original_name: "product.title"
                     },
                     filters: []
                   },
                   %Solid.Text{loc: %Loc{line: 2, column: 22}, text: "\n"}
                 ],
                 parameters: %{},
                 enumerable: %Solid.Variable{
                   loc: %Loc{line: 1, column: 24},
                   identifier: "products",
                   original_name: "products",
                   accesses: []
                 }
               },
               %Solid.ParserContext{line: 3, mode: :normal, column: 18, rest: "\n", tags: nil}
             }
    end

    test "range" do
      template = """
      {% tablerow i in (1..5) %}
        {{ i }}
      {% endtablerow %}
      """

      assert parse(template) ==
               {:ok,
                %TablerowTag{
                  loc: %Loc{line: 1, column: 1},
                  variable: %Solid.Variable{
                    loc: %Loc{line: 1, column: 13},
                    identifier: "i",
                    accesses: [],
                    original_name: "i"
                  },
                  enumerable: %Solid.Range{
                    loc: %Loc{line: 1, column: 18},
                    start: %Solid.Literal{loc: %Loc{line: 1, column: 19}, value: 1},
                    finish: %Solid.Literal{loc: %Loc{line: 1, column: 22}, value: 5}
                  },
                  parameters: %{},
                  body: [
                    %Solid.Text{loc: %Loc{line: 1, column: 27}, text: "\n  "},
                    %Solid.Object{
                      loc: %Loc{line: 2, column: 6},
                      argument: %Solid.Variable{
                        loc: %Loc{line: 2, column: 6},
                        identifier: "i",
                        accesses: [],
                        original_name: "i"
                      },
                      filters: []
                    },
                    %Solid.Text{loc: %Loc{line: 2, column: 10}, text: "\n"}
                  ]
                },
                %Solid.ParserContext{rest: "\n", line: 3, column: 18, mode: :normal, tags: nil}}
    end

    test "params" do
      template = """
      {% tablerow i in (1..5) offset: 1, limit: 2, cols: 3 %}
        {{ i }}
      {% endtablerow %}
      """

      assert parse(template) ==
               {
                 :ok,
                 %TablerowTag{
                   body: [
                     %Solid.Text{
                       loc: %Loc{column: 56, line: 1},
                       text: "\n  "
                     },
                     %Solid.Object{
                       argument: %Solid.Variable{
                         accesses: [],
                         identifier: "i",
                         loc: %Loc{column: 6, line: 2},
                         original_name: "i"
                       },
                       filters: [],
                       loc: %Loc{column: 6, line: 2}
                     },
                     %Solid.Text{
                       loc: %Loc{column: 10, line: 2},
                       text: "\n"
                     }
                   ],
                   enumerable: %Solid.Range{
                     finish: %Solid.Literal{
                       loc: %Loc{column: 22, line: 1},
                       value: 5
                     },
                     loc: %Loc{column: 18, line: 1},
                     start: %Solid.Literal{
                       loc: %Loc{column: 19, line: 1},
                       value: 1
                     }
                   },
                   loc: %Loc{column: 1, line: 1},
                   parameters: %{
                     cols: %Solid.Literal{
                       value: 3,
                       loc: %Loc{line: 1, column: 52}
                     },
                     limit: %Solid.Literal{
                       value: 2,
                       loc: %Loc{line: 1, column: 43}
                     },
                     offset: %Solid.Literal{
                       value: 1,
                       loc: %Loc{line: 1, column: 33}
                     }
                   },
                   variable: %Solid.Variable{
                     accesses: [],
                     identifier: "i",
                     loc: %Loc{column: 13, line: 1},
                     original_name: "i"
                   }
                 },
                 %Solid.ParserContext{
                   column: 18,
                   line: 3,
                   mode: :normal,
                   rest: "\n",
                   tags: nil
                 }
               }
    end
  end
end
