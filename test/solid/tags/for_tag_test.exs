defmodule Solid.Tags.ForTagTest do
  use ExUnit.Case, async: true
  alias Solid.Tags.ForTag
  alias Solid.{Lexer, ParserContext, Renderable}
  alias Solid.Parser.Loc

  defp parse(template) do
    context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

    with {:ok, tag_name, context} <- Lexer.tokenize_tag_start(context) do
      ForTag.parse(tag_name, %Loc{line: 1, column: 1}, context)
    end
  end

  describe "parse/2" do
    test "for" do
      template = """
      {% for product in collection.products %}
        {{ product.title }}
      {% endfor %}
      """

      assert parse(template) ==
               {:ok,
                %ForTag{
                  loc: %Loc{line: 1, column: 1},
                  enumerable: %Solid.Variable{
                    original_name: "collection.products",
                    loc: %Loc{column: 19, line: 1},
                    identifier: "collection",
                    accesses: [
                      %Solid.AccessLiteral{
                        loc: %Loc{column: 30, line: 1},
                        value: "products"
                      }
                    ]
                  },
                  variable: %Solid.Variable{
                    original_name: "product",
                    loc: %Loc{column: 8, line: 1},
                    identifier: "product",
                    accesses: []
                  },
                  reversed: false,
                  parameters: %{},
                  body: [
                    %Solid.Text{loc: %Loc{column: 41, line: 1}, text: "\n  "},
                    %Solid.Object{
                      loc: %Loc{column: 6, line: 2},
                      argument: %Solid.Variable{
                        original_name: "product.title",
                        loc: %Loc{column: 6, line: 2},
                        identifier: "product",
                        accesses: [
                          %Solid.AccessLiteral{
                            loc: %Loc{column: 14, line: 2},
                            value: "title"
                          }
                        ]
                      },
                      filters: []
                    },
                    %Solid.Text{loc: %Loc{column: 22, line: 2}, text: "\n"}
                  ],
                  else_body: []
                }, %ParserContext{rest: "\n", line: 3, column: 13, mode: :normal}}
    end

    test "for range" do
      template = """
      {% for i in (1..5) %}
        {{ i }}
      {% endfor %}
      """

      assert parse(template) ==
               {
                 :ok,
                 %ForTag{
                   body: [
                     %Solid.Text{
                       loc: %Loc{column: 22, line: 1},
                       text: "\n  "
                     },
                     %Solid.Object{
                       argument: %Solid.Variable{
                         original_name: "i",
                         accesses: [],
                         identifier: "i",
                         loc: %Loc{column: 6, line: 2}
                       },
                       filters: [],
                       loc: %Loc{column: 6, line: 2}
                     },
                     %Solid.Text{
                       loc: %Loc{column: 10, line: 2},
                       text: "\n"
                     }
                   ],
                   else_body: [],
                   enumerable: %Solid.Range{
                     finish: %Solid.Literal{
                       loc: %Loc{column: 17, line: 1},
                       value: 5
                     },
                     loc: %Loc{column: 13, line: 1},
                     start: %Solid.Literal{
                       loc: %Loc{column: 14, line: 1},
                       value: 1
                     }
                   },
                   loc: %Loc{column: 1, line: 1},
                   parameters: %{},
                   reversed: false,
                   variable: %Solid.Variable{
                     original_name: "i",
                     accesses: [],
                     identifier: "i",
                     loc: %Loc{column: 8, line: 1}
                   }
                 },
                 %ParserContext{
                   column: 13,
                   line: 3,
                   mode: :normal,
                   rest: "\n"
                 }
               }
    end

    test "for + else" do
      template = """
      {% for product in collection.products %}
        {{ product.title }}
      {% else %}
        The collection is empty.
      {% endfor %}
      """

      assert parse(template) ==
               {:ok,
                %ForTag{
                  loc: %Loc{line: 1, column: 1},
                  enumerable: %Solid.Variable{
                    original_name: "collection.products",
                    loc: %Loc{column: 19, line: 1},
                    identifier: "collection",
                    accesses: [
                      %Solid.AccessLiteral{
                        loc: %Loc{column: 30, line: 1},
                        value: "products"
                      }
                    ]
                  },
                  variable: %Solid.Variable{
                    original_name: "product",
                    loc: %Loc{column: 8, line: 1},
                    identifier: "product",
                    accesses: []
                  },
                  reversed: false,
                  parameters: %{},
                  body: [
                    %Solid.Text{loc: %Loc{column: 41, line: 1}, text: "\n  "},
                    %Solid.Object{
                      loc: %Loc{column: 6, line: 2},
                      argument: %Solid.Variable{
                        original_name: "product.title",
                        loc: %Loc{column: 6, line: 2},
                        identifier: "product",
                        accesses: [
                          %Solid.AccessLiteral{
                            loc: %Loc{column: 14, line: 2},
                            value: "title"
                          }
                        ]
                      },
                      filters: []
                    },
                    %Solid.Text{loc: %Loc{column: 22, line: 2}, text: "\n"}
                  ],
                  else_body: [
                    %Solid.Text{
                      loc: %Loc{column: 11, line: 3},
                      text: "\n  The collection is empty.\n"
                    }
                  ]
                }, %ParserContext{rest: "\n", line: 5, column: 13, mode: :normal}}
    end

    test "for with empty body remove empty text" do
      template = """
      {% for product in collection.products %}

      {% endfor %}
      """

      assert parse(template) ==
               {:ok,
                %ForTag{
                  loc: %Loc{column: 1, line: 1},
                  enumerable: %Solid.Variable{
                    original_name: "collection.products",
                    loc: %Loc{column: 19, line: 1},
                    identifier: "collection",
                    accesses: [
                      %Solid.AccessLiteral{
                        loc: %Loc{column: 30, line: 1},
                        value: "products"
                      }
                    ]
                  },
                  variable: %Solid.Variable{
                    original_name: "product",
                    loc: %Loc{column: 8, line: 1},
                    identifier: "product",
                    accesses: []
                  },
                  reversed: false,
                  parameters: %{},
                  body: [],
                  else_body: []
                }, %ParserContext{rest: "\n", line: 3, column: 13, mode: :normal, tags: nil}}
    end
  end

  describe "Renderable impl" do
    test "iterate through collection" do
      template = """
      {%- for product in collection -%}
        {{ product.title }}
      {%- endfor -%}
      """

      vars = %{"collection" => [%{"title" => "shoes"}, %{"title" => "shirts"}]}

      context = %Solid.Context{vars: vars}

      {:ok, tag, _rest} = parse(template)

      assert Renderable.render(tag, context, []) == {
               [["shoes"], ["shirts"]],
               %Solid.Context{
                 vars: %{
                   "collection" => [
                     %{"title" => "shoes"},
                     %{"title" => "shirts"}
                   ]
                 }
               }
             }
    end

    test "forloop data" do
      template = """
      {%- for inner in outer -%}
        {%- for i in inner -%}
          {{- forloop.parentloop.index }}-{{ forloop.index -}}
        {%- endfor -%}
      {%- endfor -%}
      """

      vars = %{"outer" => [1..3, 1..3]}

      context = %Solid.Context{vars: vars}

      {:ok, tag, _rest} = parse(template)

      assert Renderable.render(tag, context, []) == {
               [
                 [[["1", "-", "1"], ["1", "-", "2"], ["1", "-", "3"]]],
                 [[["2", "-", "1"], ["2", "-", "2"], ["2", "-", "3"]]]
               ],
               %Solid.Context{vars: %{"outer" => [1..3, 1..3]}}
             }
    end
  end
end
