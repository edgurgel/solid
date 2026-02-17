defmodule Solid.Tags.IfTagTest do
  use ExUnit.Case, async: true
  alias Solid.Tags.IfTag
  alias Solid.{Lexer, ParserContext, Renderable}
  alias Solid.Parser.Loc

  defp parse(template) do
    context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

    with {:ok, tag_name, context} <- Lexer.tokenize_tag_start(context) do
      IfTag.parse(tag_name, %Loc{line: 1, column: 1}, context)
    end
  end

  describe "parse/2" do
    test "basic if" do
      template = ~s<{% if true == false and 1 %} letter b {{ var }} {% endif %}>

      assert parse(template) ==
               {:ok,
                %IfTag{
                  elsifs: [],
                  tag_name: :if,
                  loc: %Loc{line: 1, column: 1},
                  body: [
                    %Solid.Text{
                      loc: %Loc{column: 29, line: 1},
                      text: " letter b "
                    },
                    %Solid.Object{
                      loc: %Loc{column: 42, line: 1},
                      argument: %Solid.Variable{
                        original_name: "var",
                        loc: %Loc{column: 42, line: 1},
                        identifier: "var",
                        accesses: []
                      },
                      filters: []
                    },
                    %Solid.Text{loc: %Loc{column: 48, line: 1}, text: " "}
                  ],
                  else_body: [],
                  condition: %Solid.BinaryCondition{
                    loc: %Loc{column: 7, line: 1},
                    child_condition:
                      {:and,
                       %Solid.UnaryCondition{
                         loc: %Loc{column: 25, line: 1},
                         child_condition: nil,
                         argument: %Solid.Literal{
                           loc: %Loc{column: 25, line: 1},
                           value: 1
                         }
                       }},
                    left_argument: %Solid.Literal{
                      loc: %Loc{column: 7, line: 1},
                      value: true
                    },
                    operator: :==,
                    right_argument: %Solid.Literal{
                      loc: %Loc{column: 15, line: 1},
                      value: false
                    }
                  }
                }, %ParserContext{rest: "", line: 1, column: 60, mode: :normal}}
    end

    test "basic unless" do
      template = ~s<{% unless true == false and 1 %} letter b {{ var }} {% endunless %}>

      assert parse(template) ==
               {
                 :ok,
                 %IfTag{
                   body: [
                     %Solid.Text{
                       loc: %Loc{column: 33, line: 1},
                       text: " letter b "
                     },
                     %Solid.Object{
                       argument: %Solid.Variable{
                         original_name: "var",
                         accesses: [],
                         identifier: "var",
                         loc: %Loc{column: 46, line: 1}
                       },
                       filters: [],
                       loc: %Loc{column: 46, line: 1}
                     },
                     %Solid.Text{
                       loc: %Loc{column: 52, line: 1},
                       text: " "
                     }
                   ],
                   condition: %Solid.BinaryCondition{
                     child_condition: {
                       :and,
                       %Solid.UnaryCondition{
                         argument: %Solid.Literal{
                           loc: %Loc{
                             column: 29,
                             line: 1
                           },
                           value: 1
                         },
                         child_condition: nil,
                         loc: %Loc{column: 29, line: 1}
                       }
                     },
                     left_argument: %Solid.Literal{
                       loc: %Loc{column: 11, line: 1},
                       value: true
                     },
                     loc: %Loc{column: 11, line: 1},
                     operator: :==,
                     right_argument: %Solid.Literal{
                       loc: %Loc{column: 19, line: 1},
                       value: false
                     }
                   },
                   else_body: [],
                   elsifs: [],
                   loc: %Loc{column: 1, line: 1},
                   tag_name: :unless
                 },
                 %Solid.ParserContext{
                   column: 68,
                   line: 1,
                   mode: :normal,
                   rest: ""
                 }
               }
    end

    test "elsif" do
      template = ~s<{% if 1 != 1 %}if{% elsif 1 == 1 %}elsif1{% elsif 2 == 2 %}elsif2{% endif %}>

      assert parse(template) ==
               {
                 :ok,
                 %IfTag{
                   tag_name: :if,
                   body: [
                     %Solid.Text{
                       loc: %Loc{column: 16, line: 1},
                       text: "if"
                     }
                   ],
                   condition: %Solid.BinaryCondition{
                     child_condition: nil,
                     left_argument: %Solid.Literal{
                       loc: %Loc{column: 7, line: 1},
                       value: 1
                     },
                     loc: %Loc{column: 7, line: 1},
                     operator: :!=,
                     right_argument: %Solid.Literal{
                       loc: %Loc{column: 12, line: 1},
                       value: 1
                     }
                   },
                   else_body: [],
                   elsifs: [
                     {
                       %Solid.BinaryCondition{
                         loc: %Loc{column: 27, line: 1},
                         child_condition: nil,
                         left_argument: %Solid.Literal{
                           loc: %Loc{column: 27, line: 1},
                           value: 1
                         },
                         operator: :==,
                         right_argument: %Solid.Literal{
                           loc: %Loc{column: 32, line: 1},
                           value: 1
                         }
                       },
                       [
                         %Solid.Text{
                           loc: %Loc{column: 36, line: 1},
                           text: "elsif1"
                         }
                       ]
                     },
                     {
                       %Solid.BinaryCondition{
                         loc: %Loc{column: 51, line: 1},
                         child_condition: nil,
                         left_argument: %Solid.Literal{
                           loc: %Loc{column: 51, line: 1},
                           value: 2
                         },
                         operator: :==,
                         right_argument: %Solid.Literal{
                           loc: %Loc{column: 56, line: 1},
                           value: 2
                         }
                       },
                       [
                         %Solid.Text{
                           loc: %Loc{column: 60, line: 1},
                           text: "elsif2"
                         }
                       ]
                     }
                   ],
                   loc: %Loc{column: 1, line: 1}
                 },
                 %Solid.ParserContext{
                   column: 77,
                   line: 1,
                   mode: :normal,
                   rest: ""
                 }
               }
    end

    test "elsif and else" do
      template = ~s<{% if 1 != 1 %}if{% elsif 1 == 1 %}elsif{% else %}else{% endif %}>

      assert parse(template) ==
               {
                 :ok,
                 %IfTag{
                   tag_name: :if,
                   body: [
                     %Solid.Text{
                       loc: %Loc{column: 16, line: 1},
                       text: "if"
                     }
                   ],
                   condition: %Solid.BinaryCondition{
                     child_condition: nil,
                     left_argument: %Solid.Literal{
                       loc: %Loc{column: 7, line: 1},
                       value: 1
                     },
                     loc: %Loc{column: 7, line: 1},
                     operator: :!=,
                     right_argument: %Solid.Literal{
                       loc: %Loc{column: 12, line: 1},
                       value: 1
                     }
                   },
                   else_body: [
                     %Solid.Text{loc: %Loc{column: 51, line: 1}, text: "else"}
                   ],
                   elsifs: [
                     {
                       %Solid.BinaryCondition{
                         child_condition: nil,
                         left_argument: %Solid.Literal{
                           loc: %Loc{
                             column: 27,
                             line: 1
                           },
                           value: 1
                         },
                         loc: %Loc{column: 27, line: 1},
                         operator: :==,
                         right_argument: %Solid.Literal{
                           loc: %Loc{column: 32, line: 1},
                           value: 1
                         }
                       },
                       [
                         %Solid.Text{
                           loc: %Loc{
                             column: 36,
                             line: 1
                           },
                           text: "elsif"
                         }
                       ]
                     }
                   ],
                   loc: %Loc{column: 1, line: 1}
                 },
                 %Solid.ParserContext{
                   column: 66,
                   line: 1,
                   mode: :normal,
                   rest: ""
                 }
               }
    end

    test "expected endunless" do
      template = """
      {% unless true %}
      {% else %}
      {% endif %}
      """

      assert parse(template) == {
               :error,
               "Expected 'endunless' tag. Got: Unexpected tag 'endif'",
               %{column: 1, line: 3}
             }
    end

    test "error missing endif" do
      template = ~s<{% if true == false and 1 %} letter b {{ var }}>
      assert parse(template) == {:error, "Expected 'endif'", %{column: 48, line: 1}}
    end

    test "unexpected tag after else" do
      template = """
      {% if true %}
      {% else %}
      {% endunless %}
      """

      assert parse(template) == {
               :error,
               "Expected 'endif' tag. Got: Unexpected tag 'endunless'",
               %{column: 1, line: 3}
             }
    end

    test "if with empty bodies no Text entries" do
      template = ~s<{% if true %}  {% elsif false %} {% else %} {% endif %}>

      assert parse(template) ==
               {:ok,
                %Solid.Tags.IfTag{
                  loc: %Loc{column: 1, line: 1},
                  tag_name: :if,
                  body: [],
                  elsifs: [
                    {%Solid.UnaryCondition{
                       loc: %Loc{column: 25, line: 1},
                       child_condition: nil,
                       argument: %Solid.Literal{
                         loc: %Loc{column: 25, line: 1},
                         value: false
                       },
                       argument_filters: []
                     }, []}
                  ],
                  else_body: [],
                  condition: %Solid.UnaryCondition{
                    loc: %Loc{column: 7, line: 1},
                    child_condition: nil,
                    argument: %Solid.Literal{
                      loc: %Loc{column: 7, line: 1},
                      value: true
                    },
                    argument_filters: []
                  }
                }, %ParserContext{rest: "", line: 1, column: 56, mode: :normal, tags: nil}}
    end

    test "unexpected error after if" do
      template = """
      {% if true %}
      {%%}
      """

      assert parse(template) == {
               :error,
               "Expected one of 'elsif', 'else', 'endif' tags. Got: Empty tag name",
               %{column: 3, line: 2}
             }
    end
  end

  describe "Renderable impl" do
    test "if clause" do
      template = ~s<{% if true != false and 1 %} if {% endif %}>
      context = %Solid.Context{}

      {:ok, tag, _rest} = parse(template)

      assert {[%Solid.Text{text: " if "}], ^context} = Renderable.render(tag, context, [])
    end

    test "unless clause" do
      template = ~s<{% unless false %} unless {% endunless %}>
      context = %Solid.Context{}

      {:ok, tag, _rest} = parse(template)

      assert {[%Solid.Text{text: " unless "}], ^context} = Renderable.render(tag, context, [])
    end

    test "else clause" do
      template = ~s<{% if true != false and nil %} if {% else %} else {% endif %}>
      context = %Solid.Context{}

      {:ok, tag, _rest} = parse(template)

      assert {[%Solid.Text{text: " else "}], ^context} = Renderable.render(tag, context, [])
    end

    test "unless else clause" do
      template = ~s<{% unless true %} unless {% else %} else {% endunless %}>
      context = %Solid.Context{}

      {:ok, tag, _rest} = parse(template)

      assert {[%Solid.Text{text: " else "}], ^context} = Renderable.render(tag, context, [])
    end

    test "elsif clause" do
      template =
        ~s<{% if false %} if {% elsif false %} elsif1 {% elsif nil %}{% elsif true %} elsif3 {% else %} else {% endif %}>

      context = %Solid.Context{}

      {:ok, tag, _rest} = parse(template)

      assert {[%Solid.Text{text: " elsif3 "}], ^context} = Renderable.render(tag, context, [])
    end

    test "if with filter in unary condition" do
      template = ~s<{% if items | size %} has items {% endif %}>
      context = %Solid.Context{vars: %{"items" => [1, 2, 3]}}

      {:ok, tag, _rest} = parse(template)

      assert {[%Solid.Text{text: " has items "}], _} = Renderable.render(tag, context, [])
    end

    test "if with filter in binary condition" do
      template = ~s<{% if name | upcase == "JOHN" %} match {% endif %}>
      context = %Solid.Context{vars: %{"name" => "john"}}

      {:ok, tag, _rest} = parse(template)

      assert {[%Solid.Text{text: " match "}], _} = Renderable.render(tag, context, [])
    end

    test "unless with filter in condition" do
      template = ~s({% unless items | size > 0 %} empty {% endunless %})
      context = %Solid.Context{vars: %{"items" => []}}

      {:ok, tag, _rest} = parse(template)

      assert {[%Solid.Text{text: " empty "}], _} = Renderable.render(tag, context, [])
    end
  end
end
