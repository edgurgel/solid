defmodule Solid.ParserTest do
  use ExUnit.Case, async: true
  alias Solid.Parser
  alias Solid.Tags
  alias Solid.ParserContext

  defp parse(template, opts \\ []) do
    Parser.parse(template, opts)
  end

  describe "maybe_tokenize_tag/2" do
    test "normal mode tag is found" do
      template = "{% my_tag 123 %}"
      context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

      assert Parser.maybe_tokenize_tag("my_tag", context) == {
               :tag,
               "my_tag",
               [{:integer, %{line: 1, column: 11}, 123}, {:end, %{line: 1, column: 15}}],
               %Solid.ParserContext{rest: "", line: 1, column: 17, mode: :normal, tags: nil}
             }
    end

    test "normal mode tag is not found" do
      template = "{% not_my_tag 123 %}"
      context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

      assert Parser.maybe_tokenize_tag("my_tag", context) == {
               :not_found,
               %ParserContext{
                 rest: "{% not_my_tag 123 %}",
                 line: 1,
                 column: 1,
                 mode: :normal
               }
             }
    end

    test "liquid mode tag is found" do
      template = "    my_tag 123\n"
      context = %ParserContext{rest: template, line: 1, column: 1, mode: :liquid_tag}

      assert Parser.maybe_tokenize_tag("my_tag", context) == {
               :tag,
               "my_tag",
               [
                 {:integer, %{column: 12, line: 1}, 123},
                 {:end, %{column: 15, line: 1}}
               ],
               %Solid.ParserContext{
                 column: 1,
                 line: 2,
                 mode: :liquid_tag,
                 rest: ""
               }
             }
    end

    test "liquid mode tag is found and liquid tag ends" do
      template = "    my_tag 123 %}"
      context = %ParserContext{rest: template, line: 1, column: 1, mode: :liquid_tag}

      assert Parser.maybe_tokenize_tag("my_tag", context) == {
               :tag,
               "my_tag",
               [
                 {:integer, %{column: 12, line: 1}, 123},
                 {:end, %{column: 16, line: 1}}
               ],
               %Solid.ParserContext{
                 column: 16,
                 line: 1,
                 mode: :liquid_tag,
                 rest: "%}",
                 tags: nil
               }
             }
    end

    test "liquid mode tag is not found" do
      template = "not_my_tag 123\n"
      context = %ParserContext{rest: template, line: 1, column: 1, mode: :liquid_tag}

      assert Parser.maybe_tokenize_tag("my_tag", context) == {
               :not_found,
               %ParserContext{
                 line: 1,
                 column: 1,
                 mode: :liquid_tag,
                 rest: template
               }
             }
    end
  end

  describe "remove_blank_text_if_blank_body/3" do
    test "remove text entries if all entries are blank" do
      template = """
      {% assign x = y %}
       {% comment %}
      comment
      {% endcomment %}
      {% # another comment %}
      """

      assert {:ok,
              entries = [
                %Solid.Tags.AssignTag{},
                %Solid.Text{text: "\n "},
                %Solid.Tags.CommentTag{},
                %Solid.Text{text: "\n"},
                %Solid.Tags.InlineCommentTag{},
                %Solid.Text{text: "\n"}
              ]} = parse(template)

      assert [
               %Solid.Tags.AssignTag{},
               %Solid.Tags.CommentTag{},
               %Solid.Tags.InlineCommentTag{}
             ] = Parser.remove_blank_text_if_blank_body(entries)
    end

    test "do nothing if text is not blank" do
      template = """
      {% assign x = y %}
      1 {% comment %}
      comment
      {% endcomment %}
      2 {% # another comment %}
      3
      """

      assert {:ok,
              entries = [
                %Solid.Tags.AssignTag{},
                %Solid.Text{text: "\n1 "},
                %Solid.Tags.CommentTag{},
                %Solid.Text{text: "\n2 "},
                %Solid.Tags.InlineCommentTag{},
                %Solid.Text{text: "\n3\n"}
              ]} = parse(template)

      assert ^entries = Parser.remove_blank_text_if_blank_body(entries)
    end

    test "do nothing if at least one entry is not blank" do
      template = """
      {% assign x = y %}
      {% echo 'not blank' %}
       {% comment %}
      comment
      {% endcomment %}
      {% # another comment %}
      """

      assert {:ok,
              entries = [
                %Solid.Tags.AssignTag{},
                %Solid.Text{},
                %Solid.Tags.EchoTag{},
                %Solid.Text{},
                %Solid.Tags.CommentTag{},
                %Solid.Text{},
                %Solid.Tags.InlineCommentTag{},
                %Solid.Text{}
              ]} = parse(template)

      assert ^entries = Parser.remove_blank_text_if_blank_body(entries)
    end
  end

  describe "parse_liquid_entry/1" do
    test "parse a liquid entry" do
      template = "{% echo 'yo' %} {% dont parse me just yet - %} }}"
      context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

      assert Parser.parse_liquid_entry(context) ==
               {:ok,
                [
                  %Solid.Tags.EchoTag{
                    loc: %Parser.Loc{line: 1, column: 1},
                    object: %Solid.Object{
                      loc: %Parser.Loc{line: 1, column: 9},
                      argument: %Solid.Literal{
                        loc: %Parser.Loc{line: 1, column: 9},
                        value: "yo"
                      },
                      filters: []
                    }
                  }
                ],
                %Solid.ParserContext{
                  rest: " {% dont parse me just yet - %} }}",
                  line: 1,
                  column: 16,
                  mode: :normal
                }}
    end

    test "parse a complex liquid entry" do
      template = "{% if true %} true {% endif %} {% dont parse me just yet - %} }}"
      context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

      assert {
               :ok,
               [
                 %Solid.Tags.IfTag{
                   body: [
                     %Solid.Text{loc: %Solid.Parser.Loc{line: 1, column: 14}, text: " true "}
                   ],
                   condition: %Solid.UnaryCondition{},
                   else_body: [],
                   elsifs: [],
                   tag_name: :if
                 }
               ],
               %Solid.ParserContext{
                 column: 31,
                 line: 1,
                 mode: :normal,
                 rest: " {% dont parse me just yet - %} }}"
               }
             } = Parser.parse_liquid_entry(context)
    end

    test "text" do
      template = "text {{ obj }}"
      context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

      assert Parser.parse_liquid_entry(context) ==
               {:ok,
                [
                  %Solid.Text{
                    loc: %Parser.Loc{column: 1, line: 1},
                    text: "text "
                  }
                ],
                %Solid.ParserContext{
                  rest: "{{ obj }}",
                  line: 1,
                  column: 6,
                  mode: :normal
                }}
    end

    test "object" do
      template = "{{ obj }} text"
      context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

      assert Parser.parse_liquid_entry(context) == {
               :ok,
               [
                 %Solid.Object{
                   loc: %Parser.Loc{column: 4, line: 1},
                   argument: %Solid.Variable{
                     loc: %Parser.Loc{line: 1, column: 4},
                     identifier: "obj",
                     accesses: [],
                     original_name: "obj"
                   },
                   filters: []
                 }
               ],
               %Solid.ParserContext{
                 column: 10,
                 line: 1,
                 mode: :normal,
                 rest: " text"
               }
             }
    end

    test "liquid tag changes mode" do
      template = """
      {% liquid
      echo 'ya'
      %}
      """

      context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

      assert Parser.parse_liquid_entry(context) == {
               :ok,
               [],
               %Solid.ParserContext{
                 line: 1,
                 column: 10,
                 mode: :liquid_tag,
                 rest: "\necho 'ya'\n%}\n"
               }
             }
    end

    test "tag inside liquid_tag mode" do
      template = """
      echo 'ya'
      %}
      """

      context = %ParserContext{rest: template, line: 1, column: 1, mode: :liquid_tag}

      assert Parser.parse_liquid_entry(context) == {
               :ok,
               [
                 %Solid.Tags.EchoTag{
                   loc: %Parser.Loc{line: 1, column: 1},
                   object: %Solid.Object{
                     loc: %Parser.Loc{line: 1, column: 6},
                     argument: %Solid.Literal{loc: %Parser.Loc{line: 1, column: 6}, value: "ya"},
                     filters: []
                   }
                 }
               ],
               %Solid.ParserContext{
                 column: 1,
                 line: 2,
                 mode: :liquid_tag,
                 rest: "%}\n"
               }
             }
    end

    test "end tag inside liquid_tag mode" do
      template = " %} rest"

      context = %ParserContext{rest: template, line: 1, column: 1, mode: :liquid_tag}

      assert Parser.parse_liquid_entry(context) == {
               :ok,
               [],
               %Solid.ParserContext{
                 column: 4,
                 line: 1,
                 mode: :normal,
                 rest: " rest"
               }
             }
    end

    test "end text liquid tag mode" do
      template = ""

      context = %ParserContext{rest: template, line: 1, column: 1, mode: :liquid_tag}

      assert Parser.parse_liquid_entry(context) == {
               :error,
               "Liquid tag not terminated",
               %{column: 1, line: 1},
               %Solid.ParserContext{rest: "", line: 1, column: 1, mode: :liquid_tag}
             }
    end

    test "end text normal mode" do
      template = ""

      context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

      assert Parser.parse_liquid_entry(context) == :ok
    end
  end

  describe "parse_until/3" do
    test "tag is found" do
      template = "{{ obj }} {% endif %} rest"

      context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

      assert {:ok, [%Solid.Object{}, %Solid.Text{}], "endif", [end: %{line: 1, column: 20}],
              %Solid.ParserContext{rest: " rest", line: 1, column: 22, mode: :normal}} =
               Parser.parse_until(context, "endif", "endif not found")
    end

    test "tag is not found" do
      template = "{{ obj }} {% echo 'yo' %} rest"

      context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

      assert Parser.parse_until(context, "endif", "endif not found") ==
               {:error, "endif not found", %{column: 31, line: 1}}
    end

    test "first tag found returns" do
      template = "{{ obj }} {% else %} {% endif %} rest"

      context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

      assert {:ok,
              [
                %Solid.Object{},
                %Solid.Text{}
              ], "else", [end: %{line: 1, column: 19}],
              %Solid.ParserContext{
                rest: " {% endif %} rest",
                line: 1,
                column: 21,
                mode: :normal
              }} = Parser.parse_until(context, ["endif", "else"], "else or endif not found")
    end

    test "works fine with liquid tag before returning" do
      template = """
      {{obj}}
      {% liquid
      echo 'inside liquid tag'
      %}
      {% endif %}
      """

      context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

      assert {
               :ok,
               [
                 %Solid.Object{},
                 %Solid.Text{},
                 %Solid.Tags.EchoTag{},
                 %Solid.Text{}
               ],
               "endif",
               [end: %{column: 10, line: 5}],
               %Solid.ParserContext{
                 column: 12,
                 line: 5,
                 mode: :normal,
                 rest: "\n"
               }
             } = Parser.parse_until(context, "endif", "endif not found")
    end

    test "doesn't allow liquid tag to close tag from outside" do
      template = """
      {% if true %}
      {% liquid
        endif
      %}
      """

      context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

      assert Parser.parse_until(context, "endif", "endif not found") ==
               {:error, "Expected 'endif'", %{line: 4, column: 1}}
    end

    test "doesn't allow tag to close liquid tag" do
      template = """
      {% liquid
        if true
      %}
      {% endif %}
      """

      context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

      assert Parser.parse_until(context, "endif", "endif not found") ==
               {:error, "Expected 'endif'", %{line: 4, column: 12}}
    end

    test "error found" do
      template = "{{ obj }} {% unknown_tag %} {% endif %} rest"

      context = %ParserContext{rest: template, line: 1, column: 1, mode: :normal}

      assert Parser.parse_until(context, "endif", "endif not found") ==
               {:error, "Unexpected tag 'unknown_tag'", %{line: 1, column: 11}}
    end
  end

  describe "parse/1" do
    test "object errors" do
      template = "{{ v1 v2 }} {{ v1 123 }}"

      assert parse(template) ==
               {:error,
                [
                  {"Unexpected token", %{line: 1, column: 7}},
                  {"Unexpected token", %{line: 1, column: 19}}
                ]}
    end

    test "empty object" do
      template = "{{}}"

      assert parse(template) ==
               {:ok,
                [
                  %Solid.Object{
                    loc: %Parser.Loc{column: 3, line: 1},
                    argument: %Solid.Literal{
                      loc: %Parser.Loc{column: 3, line: 1},
                      value: nil
                    },
                    filters: []
                  }
                ]}
    end

    test "object literal string single quotes" do
      template = "{{ 'a string' }}"

      assert parse(template) == {
               :ok,
               [
                 %Solid.Object{
                   loc: %Parser.Loc{column: 4, line: 1},
                   argument: %Solid.Literal{
                     loc: %Parser.Loc{column: 4, line: 1},
                     value: "a string"
                   },
                   filters: []
                 }
               ]
             }
    end

    test "object literal string double quotes" do
      template = ~s<{{ "a string" -}}>

      assert parse(template) == {
               :ok,
               [
                 %Solid.Object{
                   loc: %Parser.Loc{column: 4, line: 1},
                   argument: %Solid.Literal{
                     loc: %Parser.Loc{column: 4, line: 1},
                     value: "a string"
                   },
                   filters: []
                 }
               ]
             }
    end

    test "object literal integer" do
      template = "{{ 123 }}"

      assert parse(template) == {
               :ok,
               [
                 %Solid.Object{
                   loc: %Parser.Loc{column: 4, line: 1},
                   argument: %Solid.Literal{
                     loc: %Parser.Loc{column: 4, line: 1},
                     value: 123
                   },
                   filters: []
                 }
               ]
             }
    end

    test "object literal float" do
      template = "{{ 123.45 }}"

      assert parse(template) == {
               :ok,
               [
                 %Solid.Object{
                   loc: %Parser.Loc{column: 4, line: 1},
                   argument: %Solid.Literal{
                     loc: %Parser.Loc{column: 4, line: 1},
                     value: 123.45
                   },
                   filters: []
                 }
               ]
             }
    end

    test "object literal null" do
      template = "{{ nil }}"

      assert parse(template) == {
               :ok,
               [
                 %Solid.Object{
                   loc: %Parser.Loc{column: 4, line: 1},
                   argument: %Solid.Literal{value: nil, loc: %Parser.Loc{column: 4, line: 1}},
                   filters: []
                 }
               ]
             }
    end

    test "object literal true" do
      template = "{{ true }}"

      assert parse(template) == {
               :ok,
               [
                 %Solid.Object{
                   loc: %Parser.Loc{column: 4, line: 1},
                   argument: %Solid.Literal{
                     loc: %Parser.Loc{column: 4, line: 1},
                     value: true
                   },
                   filters: []
                 }
               ]
             }
    end

    test "object literal false" do
      template = "{{ false }}"

      assert parse(template) == {
               :ok,
               [
                 %Solid.Object{
                   loc: %Parser.Loc{column: 4, line: 1},
                   argument: %Solid.Literal{
                     loc: %Parser.Loc{column: 4, line: 1},
                     value: false
                   },
                   filters: []
                 }
               ]
             }
    end

    test "object with complex access" do
      template = "{{ greetings['first'][second].third[4][fifth['nested']]}}"

      assert parse(template) ==
               {:ok,
                [
                  %Solid.Object{
                    loc: %Parser.Loc{column: 4, line: 1},
                    argument: %Solid.Variable{
                      original_name: "greetings['first'][second].third[4][fifth['nested']]",
                      loc: %Parser.Loc{column: 4, line: 1},
                      identifier: "greetings",
                      accesses: [
                        %Solid.AccessLiteral{
                          loc: %Parser.Loc{column: 14, line: 1},
                          access_type: :brackets,
                          value: "first"
                        },
                        %Solid.AccessVariable{
                          loc: %Parser.Loc{column: 23, line: 1},
                          variable: %Solid.Variable{
                            original_name: "second",
                            loc: %Parser.Loc{column: 23, line: 1},
                            identifier: "second",
                            accesses: []
                          }
                        },
                        %Solid.AccessLiteral{
                          loc: %Parser.Loc{column: 31, line: 1},
                          access_type: :dot,
                          value: "third"
                        },
                        %Solid.AccessLiteral{
                          loc: %Parser.Loc{column: 37, line: 1},
                          access_type: :brackets,
                          value: 4
                        },
                        %Solid.AccessVariable{
                          loc: %Parser.Loc{column: 40, line: 1},
                          variable: %Solid.Variable{
                            original_name: "fifth['nested']",
                            loc: %Parser.Loc{column: 40, line: 1},
                            identifier: "fifth",
                            accesses: [
                              %Solid.AccessLiteral{
                                loc: %Parser.Loc{column: 46, line: 1},
                                access_type: :brackets,
                                value: "nested"
                              }
                            ]
                          }
                        }
                      ]
                    },
                    filters: []
                  }
                ]}
    end

    test "object filters" do
      template = "{{ false | default: 1, 2 | upcase }}"

      assert parse(template) == {
               :ok,
               [
                 %Solid.Object{
                   argument: %Solid.Literal{
                     loc: %Parser.Loc{column: 4, line: 1},
                     value: false
                   },
                   filters: [
                     %Solid.Filter{
                       function: "default",
                       loc: %Parser.Loc{column: 12, line: 1},
                       named_arguments: %{},
                       positional_arguments: [
                         %Solid.Literal{
                           loc: %Parser.Loc{
                             column: 21,
                             line: 1
                           },
                           value: 1
                         },
                         %Solid.Literal{
                           loc: %Parser.Loc{column: 24, line: 1},
                           value: 2
                         }
                       ]
                     },
                     %Solid.Filter{
                       loc: %Parser.Loc{line: 1, column: 28},
                       function: "upcase",
                       positional_arguments: [],
                       named_arguments: %{}
                     }
                   ],
                   loc: %Parser.Loc{column: 4, line: 1}
                 }
               ]
             }
    end

    test "object filter named argument" do
      template = "{{ false | replace: text: '123', number: 4 }}"

      assert parse(template) == {
               :ok,
               [
                 %Solid.Object{
                   argument: %Solid.Literal{
                     loc: %Parser.Loc{column: 4, line: 1},
                     value: false
                   },
                   filters: [
                     %Solid.Filter{
                       function: "replace",
                       loc: %Parser.Loc{column: 12, line: 1},
                       named_arguments: %{
                         "text" => %Solid.Literal{
                           loc: %Parser.Loc{column: 27, line: 1},
                           value: "123"
                         },
                         "number" => %Solid.Literal{
                           loc: %Parser.Loc{column: 42, line: 1},
                           value: 4
                         }
                       },
                       positional_arguments: []
                     }
                   ],
                   loc: %Parser.Loc{column: 4, line: 1}
                 }
               ]
             }
    end

    test "echo tag" do
      template = ~s<{% echo "I am a tag" | upcase %}>

      assert parse(template) ==
               {:ok,
                [
                  %Tags.EchoTag{
                    loc: %Parser.Loc{line: 1, column: 1},
                    object: %Solid.Object{
                      loc: %Parser.Loc{column: 9, line: 1},
                      argument: %Solid.Literal{
                        loc: %Parser.Loc{column: 9, line: 1},
                        value: "I am a tag"
                      },
                      filters: [
                        %Solid.Filter{
                          loc: %Parser.Loc{line: 1, column: 24},
                          function: "upcase",
                          positional_arguments: [],
                          named_arguments: %{}
                        }
                      ]
                    }
                  }
                ]}
    end

    test "liquid echo tag" do
      template = """
      {% liquid
      echo "hey"
      echo "I am a tag" | upcase %}
      """

      assert parse(template) ==
               {
                 :ok,
                 [
                   %Tags.EchoTag{
                     loc: %Parser.Loc{column: 10, line: 1},
                     object: %Solid.Object{
                       argument: %Solid.Literal{
                         loc: %Parser.Loc{column: 6, line: 2},
                         value: "hey"
                       },
                       filters: [],
                       loc: %Parser.Loc{column: 6, line: 2}
                     }
                   },
                   %Tags.EchoTag{
                     loc: %Parser.Loc{column: 1, line: 3},
                     object: %Solid.Object{
                       loc: %Parser.Loc{column: 6, line: 3},
                       argument: %Solid.Literal{
                         loc: %Parser.Loc{column: 6, line: 3},
                         value: "I am a tag"
                       },
                       filters: [
                         %Solid.Filter{
                           loc: %Parser.Loc{line: 3, column: 21},
                           function: "upcase",
                           positional_arguments: [],
                           named_arguments: %{}
                         }
                       ]
                     }
                   },
                   %Solid.Text{loc: %Parser.Loc{column: 30, line: 3}, text: "\n"}
                 ]
               }
    end

    test "assign tag" do
      template = ~s<{% assign myvariable1 = myvariable2 | plus: 999 %}>

      assert parse(template) ==
               {:ok,
                [
                  %Tags.AssignTag{
                    loc: %Parser.Loc{line: 1, column: 1},
                    argument: %Solid.Variable{
                      original_name: "myvariable1",
                      loc: %Parser.Loc{
                        column: 11,
                        line: 1
                      },
                      identifier: "myvariable1",
                      accesses: []
                    },
                    object: %Solid.Object{
                      loc: %Parser.Loc{column: 25, line: 1},
                      argument: %Solid.Variable{
                        original_name: "myvariable2",
                        loc: %Parser.Loc{column: 25, line: 1},
                        identifier: "myvariable2",
                        accesses: []
                      },
                      filters: [
                        %Solid.Filter{
                          loc: %Parser.Loc{line: 1, column: 39},
                          function: "plus",
                          positional_arguments: [
                            %Solid.Literal{
                              loc: %Parser.Loc{column: 45, line: 1},
                              value: 999
                            }
                          ],
                          named_arguments: %{}
                        }
                      ]
                    }
                  }
                ]}
    end

    test "capture tag" do
      template = ~s<{% capture var1 %} {{ yo }} {% endcapture %}>

      assert parse(template) == {
               :ok,
               [
                 %Tags.CaptureTag{
                   body: [
                     %Solid.Text{
                       loc: %Parser.Loc{column: 19, line: 1},
                       text: " "
                     },
                     %Solid.Object{
                       argument: %Solid.Variable{
                         original_name: "yo",
                         accesses: [],
                         identifier: "yo",
                         loc: %Parser.Loc{
                           column: 23,
                           line: 1
                         }
                       },
                       filters: [],
                       loc: %Parser.Loc{column: 23, line: 1}
                     },
                     %Solid.Text{loc: %Parser.Loc{column: 28, line: 1}, text: " "}
                   ],
                   loc: %Parser.Loc{column: 1, line: 1},
                   argument: %Solid.Variable{
                     original_name: "var1",
                     accesses: [],
                     identifier: "var1",
                     loc: %Parser.Loc{column: 12, line: 1}
                   }
                 }
               ]
             }
    end

    test "raw tag" do
      template = """
      {% raw -%}
      In Handlebars, {{ this }} will be HTML-escaped, but {{{ that }}} will not.
      {%- endraw -%}
      """

      assert parse(template) == {
               :ok,
               [
                 %Tags.RawTag{
                   loc: %Parser.Loc{line: 1, column: 1},
                   text:
                     "In Handlebars, {{ this }} will be HTML-escaped, but {{{ that }}} will not."
                 }
               ]
             }
    end

    test "liquid raw tag" do
      template = """
      {% liquid
      raw
      In Handlebars, {{ this }} will be HTML-escaped, but {{{ that }}} will not.
        %}
      endraw -%}
      """

      assert parse(template) == {
               :ok,
               [
                 %Solid.Tags.RawTag{
                   loc: %Solid.Parser.Loc{column: 10, line: 1},
                   text:
                     "In Handlebars, {{ this }} will be HTML-escaped, but {{{ that }}} will not.\n  %}"
                 }
               ]
             }
    end

    test "if tag" do
      template = ~s<# {% if true == false and 1 %} letter b {{ var }} {% endif %}>

      assert {:ok,
              [
                %Solid.Text{text: "# "},
                %Tags.IfTag{
                  tag_name: :if,
                  elsifs: [],
                  body: [
                    %Solid.Text{
                      text: " letter b "
                    },
                    %Solid.Object{
                      argument: %Solid.Variable{identifier: "var"}
                    },
                    %Solid.Text{text: " "}
                  ],
                  else_body: [],
                  condition: %Solid.BinaryCondition{
                    child_condition:
                      {:and,
                       %Solid.UnaryCondition{
                         child_condition: nil,
                         argument: %Solid.Literal{
                           value: 1
                         }
                       }},
                    left_argument: %Solid.Literal{
                      value: true
                    },
                    operator: :==,
                    right_argument: %Solid.Literal{
                      value: false
                    }
                  }
                }
              ]} = parse(template)
    end

    test "if with liquid tag inside" do
      template = """
      {% if true %}
        {% liquid
          echo 'yo'
        %}
      {% endif %}
      """

      assert {:ok,
              [
                %Solid.Tags.IfTag{
                  body: [
                    %Solid.Text{},
                    %Solid.Tags.EchoTag{},
                    %Solid.Text{}
                  ]
                },
                %Solid.Text{loc: %Solid.Parser.Loc{line: 5, column: 12}, text: "\n"}
              ]} = parse(template)
    end

    test "if with liquid tag complementing tag from outside" do
      template = """
      {% if true %}
        {% liquid
        echo 'true'
        else
        echo 'false'
        %}
      {% endif %}
      """

      assert parse(template) == {
               :error,
               [
                 {"Expected 'endif'", %{line: 5, column: 1}},
                 {"Unexpected tag 'else'", %{line: 4, column: 1}},
                 {"Unexpected tag 'endif'", %{line: 7, column: 1}}
               ]
             }
    end

    test "nested if tag" do
      template =
        ~s<{% if true %} first {% if true %} second {% endif %} third {% endif %} fourth>

      assert {:ok,
              [
                %Tags.IfTag{
                  tag_name: :if,
                  body: [
                    %Solid.Text{text: " first "},
                    %Tags.IfTag{
                      tag_name: :if,
                      body: [%Solid.Text{text: " second "}]
                    },
                    %Solid.Text{text: " third "}
                  ]
                },
                %Solid.Text{text: " fourth"}
              ]} = parse(template)
    end

    test "if else tag" do
      template = ~s<{% if true == false and 1 %} 1 {% else %} 2 {% endif %}>

      assert parse(template) ==
               {:ok,
                [
                  %Tags.IfTag{
                    tag_name: :if,
                    elsifs: [],
                    loc: %Parser.Loc{column: 1, line: 1},
                    body: [
                      %Solid.Text{loc: %Parser.Loc{column: 29, line: 1}, text: " 1 "}
                    ],
                    else_body: [
                      %Solid.Text{loc: %Parser.Loc{column: 42, line: 1}, text: " 2 "}
                    ],
                    condition: %Solid.BinaryCondition{
                      loc: %Parser.Loc{column: 7, line: 1},
                      child_condition:
                        {:and,
                         %Solid.UnaryCondition{
                           loc: %Parser.Loc{column: 25, line: 1},
                           child_condition: nil,
                           argument: %Solid.Literal{
                             loc: %Parser.Loc{column: 25, line: 1},
                             value: 1
                           }
                         }},
                      left_argument: %Solid.Literal{
                        loc: %Parser.Loc{column: 7, line: 1},
                        value: true
                      },
                      operator: :==,
                      right_argument: %Solid.Literal{
                        loc: %Parser.Loc{column: 15, line: 1},
                        value: false
                      }
                    }
                  }
                ]}
    end

    test "nested if tag under liquid tag" do
      template = """
      {% liquid
      if true
      echo 'first'
      if true
      echo 'sendo'
      endif
      echo 'third'
      endif
      echo 'fourth'
      %}
      """

      assert {
               :ok,
               [
                 %Tags.IfTag{
                   tag_name: :if,
                   elsifs: [],
                   body: [
                     %Tags.EchoTag{
                       loc: %{column: 1, line: 3},
                       object: %Solid.Object{
                         argument: %Solid.Literal{
                           loc: %Parser.Loc{
                             column: 6,
                             line: 3
                           },
                           value: "first"
                         },
                         filters: [],
                         loc: %Parser.Loc{column: 6, line: 3}
                       }
                     },
                     %Tags.IfTag{
                       tag_name: :if,
                       elsifs: [],
                       body: [
                         %Tags.EchoTag{
                           loc: %{column: 1, line: 5},
                           object: %Solid.Object{
                             argument: %Solid.Literal{
                               loc: %Parser.Loc{
                                 column: 6,
                                 line: 5
                               },
                               value: "sendo"
                             },
                             filters: [],
                             loc: %Parser.Loc{
                               column: 6,
                               line: 5
                             }
                           }
                         }
                       ],
                       condition: %Solid.UnaryCondition{
                         argument: %Solid.Literal{
                           loc: %Parser.Loc{
                             column: 4,
                             line: 4
                           },
                           value: true
                         },
                         child_condition: nil,
                         loc: %Parser.Loc{column: 4, line: 4}
                       },
                       else_body: [],
                       loc: %Parser.Loc{column: 1, line: 4}
                     },
                     %Tags.EchoTag{
                       loc: %{column: 1, line: 7},
                       object: %Solid.Object{
                         argument: %Solid.Literal{
                           loc: %Parser.Loc{
                             column: 6,
                             line: 7
                           },
                           value: "third"
                         },
                         filters: [],
                         loc: %Parser.Loc{column: 6, line: 7}
                       }
                     }
                   ],
                   condition: %Solid.UnaryCondition{
                     argument: %Solid.Literal{
                       loc: %Parser.Loc{column: 4, line: 2},
                       value: true
                     },
                     child_condition: nil,
                     loc: %Parser.Loc{column: 4, line: 2}
                   },
                   else_body: [],
                   loc: %Parser.Loc{column: 10, line: 1}
                 },
                 %Tags.EchoTag{
                   loc: %{column: 1, line: 9},
                   object: %Solid.Object{
                     argument: %Solid.Literal{
                       loc: %Parser.Loc{column: 6, line: 9},
                       value: "fourth"
                     },
                     filters: [],
                     loc: %Parser.Loc{column: 6, line: 9}
                   }
                 },
                 %Solid.Text{
                   loc: %Parser.Loc{column: 3, line: 10},
                   text: "\n"
                 }
               ]
             } = parse(template)
    end

    test "for tag" do
      template = """
      {% for i in array %} {{i}} {%- endfor -%}
      """

      assert parse(template) == {
               :ok,
               [
                 %Tags.ForTag{
                   loc: %Parser.Loc{column: 1, line: 1},
                   body: [
                     %Solid.Text{loc: %Parser.Loc{column: 21, line: 1}, text: " "},
                     %Solid.Object{
                       loc: %Parser.Loc{column: 24, line: 1},
                       argument: %Solid.Variable{
                         original_name: "i",
                         loc: %Parser.Loc{column: 24, line: 1},
                         identifier: "i",
                         accesses: []
                       },
                       filters: []
                     }
                   ],
                   else_body: [],
                   enumerable: %Solid.Variable{
                     original_name: "array",
                     loc: %Parser.Loc{column: 13, line: 1},
                     identifier: "array",
                     accesses: []
                   },
                   parameters: %{},
                   reversed: false,
                   variable: %Solid.Variable{
                     original_name: "i",
                     loc: %Parser.Loc{column: 8, line: 1},
                     identifier: "i",
                     accesses: []
                   }
                 }
               ]
             }
    end

    test "case tag" do
      template = """
      {% case product %}
      ignored
      {% when 'shoes' %}
        Shoes
      {% when 'shirts' %}
        Shirts
      {% endcase %}
      """

      assert parse(template) == {
               :ok,
               [
                 %Solid.Tags.CaseTag{
                   cases: [
                     {[
                        %Solid.Literal{
                          loc: %Parser.Loc{column: 9, line: 3},
                          value: "shoes"
                        }
                      ],
                      [
                        %Solid.Text{
                          loc: %Parser.Loc{column: 19, line: 3},
                          text: "\n  Shoes\n"
                        }
                      ]},
                     {[
                        %Solid.Literal{
                          loc: %Parser.Loc{column: 9, line: 5},
                          value: "shirts"
                        }
                      ],
                      [
                        %Solid.Text{
                          loc: %Parser.Loc{column: 20, line: 5},
                          text: "\n  Shirts\n"
                        }
                      ]}
                   ],
                   loc: %Parser.Loc{column: 1, line: 1},
                   argument: %Solid.Variable{
                     original_name: "product",
                     accesses: [],
                     identifier: "product",
                     loc: %Parser.Loc{column: 9, line: 1}
                   }
                 },
                 %Solid.Text{
                   loc: %Parser.Loc{column: 14, line: 7},
                   text: "\n"
                 }
               ]
             }
    end

    test "cycle tag" do
      template = ~s<{% cycle var1, "b", 1 %}>

      assert parse(template) == {
               :ok,
               [
                 %Tags.CycleTag{
                   loc: %Parser.Loc{column: 1, line: 1},
                   name: nil,
                   values: [
                     %Solid.Variable{
                       original_name: "var1",
                       loc: %Parser.Loc{column: 10, line: 1},
                       identifier: "var1",
                       accesses: []
                     },
                     %Solid.Literal{loc: %Parser.Loc{column: 16, line: 1}, value: "b"},
                     %Solid.Literal{loc: %Parser.Loc{column: 21, line: 1}, value: 1}
                   ]
                 }
               ]
             }
    end

    test "increment tag" do
      template = ~s<{% increment var1 %}>

      assert parse(template) == {
               :ok,
               [
                 %Solid.Tags.CounterTag{
                   loc: %Solid.Parser.Loc{column: 1, line: 1},
                   argument: %Solid.Variable{
                     original_name: "var1",
                     loc: %Solid.Parser.Loc{column: 14, line: 1},
                     identifier: "var1",
                     accesses: []
                   },
                   operation: :increment
                 }
               ]
             }
    end

    test "decrement tag" do
      template = ~s<{% decrement var1 %}>

      assert parse(template) == {
               :ok,
               [
                 %Solid.Tags.CounterTag{
                   loc: %Solid.Parser.Loc{column: 1, line: 1},
                   argument: %Solid.Variable{
                     original_name: "var1",
                     loc: %Solid.Parser.Loc{column: 14, line: 1},
                     identifier: "var1",
                     accesses: []
                   },
                   operation: :decrement
                 }
               ]
             }
    end

    test "continue tag" do
      template = ~s<{% continue %}>

      assert parse(template) ==
               {:ok, [%Tags.ContinueTag{loc: %Parser.Loc{column: 1, line: 1}}]}
    end

    test "break tag" do
      template = ~s<{% break %}>

      assert parse(template) == {:ok, [%Tags.BreakTag{loc: %Parser.Loc{column: 1, line: 1}}]}
    end

    test "comment tag" do
      template = """
      1
      {% comment %}
      Commented
      {% endcomment %}
      2
      {{ var }}
      """

      assert parse(template) ==
               {
                 :ok,
                 [
                   %Solid.Text{loc: %Parser.Loc{column: 1, line: 1}, text: "1\n"},
                   %Solid.Tags.CommentTag{loc: %Parser.Loc{column: 1, line: 2}},
                   %Solid.Text{loc: %Parser.Loc{column: 17, line: 4}, text: "\n2\n"},
                   %Solid.Object{
                     loc: %Solid.Parser.Loc{column: 4, line: 6},
                     argument: %Solid.Variable{
                       original_name: "var",
                       loc: %Solid.Parser.Loc{column: 4, line: 6},
                       identifier: "var",
                       accesses: []
                     },
                     filters: []
                   },
                   %Solid.Text{loc: %Parser.Loc{column: 10, line: 6}, text: "\n"}
                 ]
               }
    end

    test "liquid comment tag" do
      template = """
      {% liquid
      comment this is a comment
      endcomment
      %}
      """

      assert parse(template) == {
               :ok,
               [
                 %Solid.Tags.CommentTag{loc: %Parser.Loc{column: 10, line: 1}},
                 %Solid.Text{loc: %Parser.Loc{column: 3, line: 4}, text: "\n"}
               ]
             }
    end

    test "inline comment tag" do
      template = """

      {%-
        # Lorem ipsum dolor sit amet, consectetur adipiscing elit.
        # Something else
        -%}
      """

      assert parse(template) ==
               {:ok, [%Tags.InlineCommentTag{loc: %Parser.Loc{column: 1, line: 2}}]}
    end

    test "inline comment tag inside liquid tag" do
      template = """
      {%- liquid
      # Lorem ipsum
      # dolor

      # more text
      # explanation
      echo 'Hi '

      # Just a comment
      echo 'there!'
      -%}
      """

      assert parse(template) == {
               :ok,
               [
                 %Tags.InlineCommentTag{loc: %Parser.Loc{column: 11, line: 1}},
                 %Tags.InlineCommentTag{loc: %Parser.Loc{column: 1, line: 3}},
                 %Tags.InlineCommentTag{loc: %Parser.Loc{column: 1, line: 4}},
                 %Tags.InlineCommentTag{loc: %Parser.Loc{column: 1, line: 6}},
                 %Tags.EchoTag{
                   loc: %Parser.Loc{column: 1, line: 7},
                   object: %Solid.Object{
                     argument: %Solid.Literal{
                       loc: %Parser.Loc{column: 6, line: 7},
                       value: "Hi "
                     },
                     filters: [],
                     loc: %Parser.Loc{column: 6, line: 7}
                   }
                 },
                 %Tags.InlineCommentTag{loc: %Parser.Loc{column: 1, line: 8}},
                 %Tags.EchoTag{
                   loc: %Parser.Loc{column: 1, line: 10},
                   object: %Solid.Object{
                     argument: %Solid.Literal{
                       loc: %Parser.Loc{column: 6, line: 10},
                       value: "there!"
                     },
                     filters: [],
                     loc: %Parser.Loc{column: 6, line: 10}
                   }
                 }
               ]
             }
    end

    test "custom tag get_current_year" do
      template = "{% get_current_year %}"

      assert parse(template) ==
               {:error, [{"Unexpected tag 'get_current_year'", %{line: 1, column: 1}}]}

      tags =
        Solid.Tag.default_tags()
        |> Map.put("get_current_year", CustomTags.CurrentYear)

      assert parse(template, tags: tags) ==
               {:ok, [%CustomTags.CurrentYear{loc: %Parser.Loc{column: 1, line: 1}}]}
    end

    test "liquid tag can't close a tag" do
      template = "{% if true %}1{% liquid endif %}"

      assert parse(template) == {
               :error,
               [
                 {"Expected 'endif'", %{column: 31, line: 1}},
                 {"Unexpected tag 'endif'", %{column: 24, line: 1}}
               ]
             }
    end
  end

  describe "parse/1 errors" do
    test "empty brackets" do
      template = "{{ [] }}"

      assert parse(template) == {:error, [{"Argument expected", %{line: 1, column: 4}}]}
    end

    test "incomplete filter arguments" do
      template = "{{ object | default: }}"

      assert parse(template) == {:error, [{"Arguments expected", %{line: 1, column: 20}}]}
    end

    test "incomplete filter" do
      template = "{{ object | upcase | }}"

      assert parse(template) == {:error, [{"Filter expected", %{column: 20, line: 1}}]}
    end

    test "unknown tags" do
      template = """
      {% endunless %}

      {% endunless %}
      """

      assert parse(template) ==
               {:error,
                [
                  {"Unexpected tag 'endunless'", %{column: 1, line: 1}},
                  {"Unexpected tag 'endunless'", %{line: 3, column: 1}}
                ]}
    end

    test "broken tag" do
      template = "{% if - %}"

      assert parse(template) == {:error, [{"Unexpected character '-'", %{column: 7, line: 1}}]}
    end

    test "incomplete object" do
      template = "{{ abc"

      assert parse(template) ==
               {:error,
                [
                  {
                    "Tag or Object not properly terminated",
                    %{column: 1, line: 1}
                  }
                ]}
    end

    test "incomplete tag" do
      template = "{% if a == 3"

      assert parse(template) ==
               {:error,
                [
                  {
                    "Tag or Object not properly terminated",
                    %{column: 1, line: 1}
                  }
                ]}
    end

    test "incomplete liquid tag" do
      template = """
      {% liquid
      if true
      """

      assert {:error, _} = parse(template)
    end
  end
end
