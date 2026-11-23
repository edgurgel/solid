defmodule Solid.Tags.CaseTagTest do
  use ExUnit.Case, async: true
  alias Solid.Tags.CaseTag
  alias Solid.{Lexer, ParserContext, Renderable}
  alias Solid.Parser.Loc

  defp parse(template) do
    context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

    with {:ok, tag_name, context} <- Lexer.tokenize_tag_start(context) do
      CaseTag.parse(tag_name, %Loc{line: 1, column: 1}, context)
    end
  end

  describe "parse/2" do
    test "case" do
      template = """
      {% case product %}
      ignored
      {% when 'shoes' %}
        Shoes
      {% when 'shirts' %}
        Shirts
      {% endcase %}
      """

      assert parse(template) ==
               {
                 :ok,
                 %CaseTag{
                   cases: [
                     {[%Solid.Literal{loc: %Loc{column: 9, line: 3}, value: "shoes"}],
                      [%Solid.Text{loc: %Loc{column: 19, line: 3}, text: "\n  Shoes\n"}]},
                     {[%Solid.Literal{loc: %Loc{column: 9, line: 5}, value: "shirts"}],
                      [%Solid.Text{loc: %Loc{column: 20, line: 5}, text: "\n  Shirts\n"}]}
                   ],
                   loc: %Loc{column: 1, line: 1},
                   argument: %Solid.Variable{
                     original_name: "product",
                     accesses: [],
                     identifier: "product",
                     loc: %Loc{column: 9, line: 1}
                   }
                 },
                 %ParserContext{
                   column: 14,
                   line: 7,
                   mode: :normal,
                   rest: "\n",
                   tags: nil
                 }
               }
    end

    test "case with unordered when and else" do
      template = """
      {% case product %}
      {% when 'shoes' %}
        Shoes
      {% else %}
        else1
      {% when 'shirts' %}
        Shirts
      {% else %}
        else2
      {% endcase %}
      """

      assert parse(template) ==
               {
                 :ok,
                 %Solid.Tags.CaseTag{
                   argument: %Solid.Variable{
                     original_name: "product",
                     accesses: [],
                     identifier: "product",
                     loc: %Loc{column: 9, line: 1}
                   },
                   cases: [
                     {
                       [
                         %Solid.Literal{
                           loc: %Loc{column: 9, line: 2},
                           value: "shoes"
                         }
                       ],
                       [
                         %Solid.Text{
                           loc: %Loc{column: 19, line: 2},
                           text: "\n  Shoes\n"
                         }
                       ]
                     },
                     {:else,
                      [
                        %Solid.Text{
                          loc: %Solid.Parser.Loc{column: 11, line: 4},
                          text: "\n  else1\n"
                        }
                      ]},
                     {
                       [
                         %Solid.Literal{
                           loc: %Loc{column: 9, line: 6},
                           value: "shirts"
                         }
                       ],
                       [
                         %Solid.Text{
                           loc: %Loc{column: 20, line: 6},
                           text: "\n  Shirts\n"
                         }
                       ]
                     },
                     {:else,
                      [
                        %Solid.Text{
                          loc: %Solid.Parser.Loc{column: 11, line: 8},
                          text: "\n  else2\n"
                        }
                      ]}
                   ],
                   loc: %Solid.Parser.Loc{column: 1, line: 1}
                 },
                 %Solid.ParserContext{
                   column: 14,
                   line: 10,
                   mode: :normal,
                   rest: "\n",
                   tags: nil
                 }
               }
    end

    test "else" do
      template = """
      {% case product %}
      {% when 'shoes' %}
        Shoes
      {% else %}
        Else
      {% endcase %}
      """

      assert parse(template) ==
               {
                 :ok,
                 %CaseTag{
                   cases: [
                     {[
                        %Solid.Literal{
                          loc: %Loc{column: 9, line: 2},
                          value: "shoes"
                        }
                      ],
                      [
                        %Solid.Text{
                          loc: %Loc{column: 19, line: 2},
                          text: "\n  Shoes\n"
                        }
                      ]},
                     {:else,
                      [
                        %Solid.Text{
                          loc: %Solid.Parser.Loc{column: 11, line: 4},
                          text: "\n  Else\n"
                        }
                      ]}
                   ],
                   loc: %Loc{column: 1, line: 1},
                   argument: %Solid.Variable{
                     original_name: "product",
                     accesses: [],
                     identifier: "product",
                     loc: %Loc{column: 9, line: 1}
                   }
                 },
                 %ParserContext{
                   column: 14,
                   line: 6,
                   mode: :normal,
                   rest: "\n"
                 }
               }
    end

    test "when with variable" do
      template = """
      {% case product %}
      {% when 'shoes' %}
        Shoes
      {% when shirt %}
        Shirts
      {% endcase %}
      """

      assert parse(template) == {
               :ok,
               %CaseTag{
                 loc: %Loc{column: 1, line: 1},
                 argument: %Solid.Variable{
                   original_name: "product",
                   loc: %Loc{column: 9, line: 1},
                   identifier: "product",
                   accesses: []
                 },
                 cases: [
                   {[
                      %Solid.Literal{
                        loc: %Loc{column: 9, line: 2},
                        value: "shoes"
                      }
                    ],
                    [
                      %Solid.Text{
                        loc: %Loc{column: 19, line: 2},
                        text: "\n  Shoes\n"
                      }
                    ]},
                   {[
                      %Solid.Variable{
                        original_name: "shirt",
                        loc: %Loc{column: 9, line: 4},
                        identifier: "shirt",
                        accesses: []
                      }
                    ],
                    [
                      %Solid.Text{
                        loc: %Loc{column: 17, line: 4},
                        text: "\n  Shirts\n"
                      }
                    ]}
                 ]
               },
               %ParserContext{
                 column: 14,
                 line: 6,
                 mode: :normal,
                 rest: "\n",
                 tags: nil
               }
             }
    end

    test "multiple options" do
      template =
        "{% case condition %}{% when 1, 2 or 3 %} its 1 or 2 or 3 {% when 3, 4 %} its 4 {% endcase %}"

      assert parse(template) == {
               :ok,
               %CaseTag{
                 cases: [
                   {
                     [
                       %Solid.Literal{loc: %Loc{column: 29, line: 1}, value: 1},
                       %Solid.Literal{loc: %Loc{column: 32, line: 1}, value: 2},
                       %Solid.Literal{loc: %Loc{column: 37, line: 1}, value: 3}
                     ],
                     [
                       %Solid.Text{loc: %Loc{column: 41, line: 1}, text: " its 1 or 2 or 3 "}
                     ]
                   },
                   {
                     [
                       %Solid.Literal{loc: %Loc{column: 66, line: 1}, value: 3},
                       %Solid.Literal{loc: %Loc{column: 69, line: 1}, value: 4}
                     ],
                     [%Solid.Text{loc: %Loc{column: 73, line: 1}, text: " its 4 "}]
                   }
                 ],
                 loc: %Loc{column: 1, line: 1},
                 argument: %Solid.Variable{
                   original_name: "condition",
                   accesses: [],
                   identifier: "condition",
                   loc: %Loc{column: 9, line: 1}
                 }
               },
               %Solid.ParserContext{
                 column: 93,
                 line: 1,
                 mode: :normal,
                 rest: "",
                 tags: nil
               }
             }
    end

    test "missing endcase" do
      template = """
      {% case product %}
      ignored
      {% when 'shoes' %}
        Shoes
      {% when 'shirts' %}
        Shirts
      """

      assert parse(template) == {:error, "Expected endcase", %{column: 1, line: 7}}
    end

    test "extra tokens on when" do
      template = """
      {% case product %}
      ignored
      {% when 'shoes' == two %}
        Shoes
      {% else true %}
        Shirts
      {% endcase %}
      """

      assert parse(template) == {:error, "Expected ',' or 'or'", %{column: 17, line: 3}}
    end

    test "'and' between when values" do
      template = "{% case title %}{% when 'bar' and 'Hello', 'Hello' %}bar{% endcase %}"

      assert parse(template) == {:error, "Expected ',' or 'or'", %{column: 31, line: 1}}
    end

    test "extra tokens on else" do
      template = """
      {% case product %}
      ignored
      {% when 'shoes' %}
        Shoes
      {% else true %}
        Shirts
      {% endcase %}
      """

      assert parse(template) == {:error, "Unexpected token on else", %{column: 9, line: 5}}
    end

    test "extra tokens on endcase" do
      template = """
      {% case product %}
      ignored
      {% when 'shoes' %}
        Shoes
      {% else %}
        Shirts
      {% endcase true %}
      """

      assert parse(template) == {:error, "Unexpected token on endcase", %{column: 12, line: 7}}
    end

    test "unexpected character" do
      template = """
      {% case product - 1 %}
      ignored
      {% when 'shoes' == two %}
        Shoes
      {% else true %}
        Shirts
      {% endcase %}
      """

      assert parse(template) == {:error, "Unexpected character '-'", %{column: 17, line: 1}}
    end
  end

  describe "blank bodies" do
    test "whitespace is removed from every branch when all of them are blank" do
      template = ~s<{% case x %} {% when 1 %} {% assign a = 1 %} {% else %} {% endcase %}>

      assert {:ok, %CaseTag{cases: [{_, [%Solid.Tags.AssignTag{}]}, {:else, []}], blank: true}, _} =
               parse(template)
    end

    test "blank branch keeps its whitespace when another branch has output" do
      template = ~s<{% case x %}{% when 1 %} {% when 2 %}{{ y }}{% endcase %}>

      assert {:ok, %CaseTag{cases: [{_, [%Solid.Text{text: " "}]}, {_, [%Solid.Object{}]}]}, _} =
               parse(template)
    end

    test "output before the first when keeps the whitespace" do
      template = ~s<{% case x %}{{ y }}{% when 1 %} {% endcase %}>

      assert {:ok, %CaseTag{cases: [{_, [%Solid.Text{text: " "}]}], blank: false}, _} =
               parse(template)
    end

    test "text before the first when keeps the whitespace" do
      template = ~s<{% case x %}text{% when 1 %} {% endcase %}>

      assert {:ok, %CaseTag{cases: [{_, [%Solid.Text{text: " "}]}], blank: false}, _} =
               parse(template)
    end

    test "nested blank if is stripped together with the case" do
      template = ~s<{% case x %}{% when 1 %} {% if true %} {% endif %} {% endcase %}>

      assert {:ok, %CaseTag{cases: [{_, [%Solid.Tags.IfTag{body: []}]}], blank: true}, _} =
               parse(template)
    end

    test "nested if with output keeps the case's whitespace" do
      template = ~s<{% case x %}{% when 1 %} {% if true %}{{ y }}{% endif %} {% endcase %}>

      assert {:ok, %CaseTag{cases: [{_, [%Solid.Text{}, %Solid.Tags.IfTag{}, %Solid.Text{}]}]}, _} =
               parse(template)
    end

    test "blank case inside an if is stripped together with the if" do
      template =
        "!{% if true %}\n  {% case 1 %}\n  {% when 1 %}\n    {% assign a = 1 %}\n  {% endcase %}\n{% endif %}!"

      assert template |> Solid.parse!() |> Solid.render!(%{}) |> to_string() == "!!"
    end

    test "output in a branch that is not rendered keeps whitespace in every branch" do
      template =
        "!{% assign x = 1 %}{% case x %}\n\n  {% when 1 %}\n    {% assign foo = 'bar' %}\n\n  {% when 2 %}\n    {{ '' }}\n\n{% endcase %}!"

      assert template |> Solid.parse!() |> Solid.render!(%{}) |> to_string() == "!\n    \n\n  !"
    end
  end

  describe "Solid.Block impl" do
    test "blank when every branch is blank" do
      {:ok, tag, _} =
        parse(~s<{% case x %} {% when 1 %} {% else %}{% assign a = 1 %}{% endcase %}>)

      assert Solid.Block.blank?(tag)
    end

    test "not blank when a when body has output" do
      {:ok, tag, _} = parse(~s<{% case x %}{% when 1 %} {% when 2 %}text{% endcase %}>)

      refute Solid.Block.blank?(tag)
    end

    test "not blank when the else body has output" do
      {:ok, tag, _} = parse(~s<{% case x %}{% when 1 %} {% else %}{{ y }}{% endcase %}>)

      refute Solid.Block.blank?(tag)
    end
  end

  describe "Renderable impl" do
    test "when blank and when empty check the case value" do
      render = fn template, vars ->
        {:ok, parsed} = Solid.parse(template)
        {:ok, iodata, []} = Solid.render(parsed, vars)
        IO.iodata_to_binary(iodata)
      end

      for {value, blank?, empty?} <- [
            {"", true, true},
            {" ", true, false},
            {"a", false, false},
            {[], true, true},
            {%{}, true, true},
            {nil, true, false},
            {false, true, false},
            {0, false, false}
          ] do
        vars = %{"x" => value}
        expected = fn match? -> if match?, do: "T", else: "F" end

        assert render.("{% case x %}{% when blank %}T{% else %}F{% endcase %}", vars) ==
                 expected.(blank?),
               "#{inspect(value)} when blank"

        assert render.("{% case x %}{% when empty %}T{% else %}F{% endcase %}", vars) ==
                 expected.(empty?),
               "#{inspect(value)} when empty"
      end
    end

    test "case blank and case empty read as ''" do
      template =
        "{% case empty %}{% when '' %}T{% else %}F{% endcase %}" <>
          "{% case blank %}{% when nil %}T{% else %}F{% endcase %}"

      {:ok, parsed} = Solid.parse(template)
      {:ok, iodata, []} = Solid.render(parsed, %{})

      assert IO.iodata_to_binary(iodata) == "TF"
    end

    test "renders the right case with literal" do
      template = """
      {% case product %}
      {% when 'shoes' %}
        Shoes
      {% when 'shirts' %}
        Shirts
      {% endcase %}
      """

      context = %Solid.Context{vars: %{"product" => "shoes"}}

      {:ok, tag, _rest} = parse(template)

      assert Renderable.render(tag, context, []) ==
               {
                 [
                   %Solid.Text{
                     loc: %Solid.Parser.Loc{column: 19, line: 2},
                     text: "\n  Shoes\n"
                   }
                 ],
                 context
               }
    end

    test "renders the right case with variable" do
      template = """
      {% case product %}
      {% when 'shoes' %}
        Shoes
      {% when shirts %}
        Shirts
      {% endcase %}
      """

      context = %Solid.Context{vars: %{"product" => "shirt", "shirts" => "shirt"}}

      {:ok, tag, _rest} = parse(template)

      assert Renderable.render(tag, context, []) ==
               {[
                  %Solid.Text{
                    loc: %Loc{column: 18, line: 4},
                    text: "\n  Shirts\n"
                  }
                ], context}
    end

    test "renders multiple whens" do
      template = """
      {%- case product -%}
      {%- when 'shoes' -%}
        Shoes
      {%- when item -%}
        Shoes also
      {%- endcase -%}
      """

      context = %Solid.Context{vars: %{"product" => "shoes", "item" => "shoes"}}

      {:ok, tag, _rest} = parse(template)

      assert Renderable.render(tag, context, []) ==
               {[
                  %Solid.Text{loc: %Loc{column: 3, line: 3}, text: "Shoes"},
                  %Solid.Text{loc: %Loc{column: 3, line: 5}, text: "Shoes also"}
                ], context}
    end
  end
end
