defmodule Solid.Tags.IfTagTest do
  use ExUnit.Case, async: true
  alias Solid.Tags.IfTag
  alias Solid.{Lexer, ParserContext, Renderable}
  alias Solid.Parser.Loc

  defp parse(template, opts \\ []) do
    context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal, opts: opts}

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
                  },
                  blank: true
                }, %ParserContext{rest: "", line: 1, column: 56, mode: :normal, tags: nil}}
    end

    test "blank branch keeps its text when another branch has output" do
      template = ~s<{% if true %}  {% elsif false %}{{ x }}{% else %} {% endif %}>

      assert {:ok, %IfTag{body: body, elsifs: [{_, elsif_body}], else_body: else_body}, _} =
               parse(template)

      assert [%Solid.Text{text: "  "}] = body
      assert [%Solid.Object{}] = elsif_body
      assert [%Solid.Text{text: " "}] = else_body
    end

    test "nested blank if is stripped together with its parent" do
      template = ~s<{% if true %} {% if true %} {% assign a = 1 %} {% endif %} {% endif %}>

      assert {:ok, %IfTag{body: [%IfTag{body: [%Solid.Tags.AssignTag{}]}]}, _} = parse(template)
    end

    test "nested if with output keeps the parent's text" do
      template = ~s<{% if true %} {% if true %} {% else %}{{ x }}{% endif %} {% endif %}>

      assert {:ok, %IfTag{body: [%Solid.Text{}, %IfTag{body: [%Solid.Text{}]}, %Solid.Text{}]}, _} =
               parse(template)
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

      {:ok, tag, _rest} = parse(template, filters_in_conditional_tags: true)

      assert {[%Solid.Text{text: " has items "}], _} = Renderable.render(tag, context, [])
    end

    test "if with filter in binary condition" do
      template = ~s<{% if name | upcase == "JOHN" %} match {% endif %}>
      context = %Solid.Context{vars: %{"name" => "john"}}

      {:ok, tag, _rest} = parse(template, filters_in_conditional_tags: true)

      assert {[%Solid.Text{text: " match "}], _} = Renderable.render(tag, context, [])
    end

    test "unless with filter in condition" do
      template = ~s({% unless items | size > 0 %} empty {% endunless %})
      context = %Solid.Context{vars: %{"items" => []}}

      {:ok, tag, _rest} = parse(template, filters_in_conditional_tags: true)

      assert {[%Solid.Text{text: " empty "}], _} = Renderable.render(tag, context, [])
    end
  end

  describe "Solid.Block impl" do
    test "blank when every branch is blank" do
      {:ok, tag, _} = parse(~s<{% if a %} {% elsif b %}{% assign c = 1 %}{% else %} {% endif %}>)

      assert Solid.Block.blank?(tag)
    end

    test "not blank when the if body has output" do
      {:ok, tag, _} = parse(~s<{% if a %}{{ x }}{% else %} {% endif %}>)

      refute Solid.Block.blank?(tag)
    end

    test "not blank when an elsif body has output" do
      {:ok, tag, _} = parse(~s<{% if a %} {% elsif b %}{{ x }}{% endif %}>)

      refute Solid.Block.blank?(tag)
    end

    test "not blank when the else body has output" do
      {:ok, tag, _} = parse(~s<{% unless a %} {% else %}text{% endunless %}>)

      refute Solid.Block.blank?(tag)
    end
  end

  describe "rendering whitespace in blank bodies" do
    defp render(template), do: template |> Solid.parse!() |> Solid.render!(%{}) |> to_string()

    test "nested if blocks with only assigns render nothing" do
      template =
        "!{% if true %}\n\n{% assign bar = 'foo' %}\n{% if true %}\n\n\n    {% assign foo = 'bar' %}\n\n{% endif %}\n\n\n{% endif %}!"

      assert render(template) == "!!"
    end

    test "nested unless blocks with only assigns render nothing" do
      template =
        "!{% unless false %}\n\n{% assign bar = 'foo' %}\n{% unless false %}\n\n\n    {% assign foo = 'bar' %}\n\n{% endunless %}\n\n\n{% endunless %}!"

      assert render(template) == "!!"
    end

    test "output in a branch that is not rendered keeps whitespace in every branch" do
      template =
        "!{% if 1 %}\n\n{% assign bar = 'foo' %}\n{% if true %}\n\n    {% assign foo = 'bar' %}\n\n{% else %}\n    {{ '' }}\n{% endif %}\n\n\n{% endif %}!"

      assert render(template) == "!\n\n\n\n\n    \n\n\n\n\n!"
    end
  end
end
