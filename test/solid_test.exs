defmodule SolidTest do
  use ExUnit.Case, async: true
  alias Solid.ParserError

  defmodule TestFileSystem do
    @behaviour Solid.FileSystem

    @impl true
    def read_template_file("error", _opts), do: {:ok, "{% error %}"}
    def read_template_file("missing_var", _opts), do: {:ok, "{{ var3 }}"}
  end

  describe "parser/2" do
    test "basic" do
      template = "{{ form.title }}"

      assert Solid.parse(template) ==
               {:ok,
                %Solid.Template{
                  parsed_template: [
                    %Solid.Object{
                      loc: %Solid.Parser.Loc{column: 4, line: 1},
                      argument: %Solid.Variable{
                        original_name: "form.title",
                        loc: %Solid.Parser.Loc{column: 4, line: 1},
                        identifier: "form",
                        accesses: [
                          %Solid.AccessLiteral{
                            loc: %Solid.Parser.Loc{column: 9, line: 1},
                            value: "title"
                          }
                        ]
                      },
                      filters: []
                    }
                  ]
                }}
    end

    test "single error" do
      template = "{{ form.title"

      assert Solid.parse(template) == {
               :error,
               %Solid.TemplateError{
                 errors: [
                   %Solid.ParserError{
                     meta: %{line: 1, column: 1},
                     reason: "Tag or Object not properly terminated",
                     text: "{{ form.title"
                   }
                 ]
               }
             }
    end

    test "multiple errors" do
      template = """
      {{ - }}

      {% unknown %}

      {% if true %}
      {% endunless % }
      {% echo 'yo' %}
      """

      assert Solid.parse(template) == {
               :error,
               %Solid.TemplateError{
                 errors: [
                   %Solid.ParserError{
                     meta: %{column: 4, line: 1},
                     reason: "Unexpected character '-'",
                     text: "{{ - }}"
                   },
                   %Solid.ParserError{
                     meta: %{column: 1, line: 3},
                     reason: "Unexpected tag 'unknown'",
                     text: "{% unknown %}"
                   },
                   %Solid.ParserError{
                     meta: %{column: 1, line: 6},
                     reason:
                       "Expected one of 'elsif', 'else', 'endif' tags. Got: Unexpected tag 'endunless'",
                     text: "{% endunless % }"
                   },
                   %Solid.ParserError{
                     meta: %{column: 1, line: 6},
                     reason: "Unexpected tag 'endunless'",
                     text: "{% endunless % }"
                   }
                 ]
               }
             }
    end

    test "errors inside render tag" do
      template = """
      begin
      {% render 'error' %}
      end
      """

      template = Solid.parse!(template)

      assert Solid.render(template, %{}, file_system: {TestFileSystem, nil}) ==
               {:ok, ["begin\n", [], "\nend\n"],
                [
                  %Solid.TemplateError{
                    errors: [
                      %ParserError{
                        reason: "Unexpected tag 'error'",
                        meta: %{line: 1, column: 1},
                        text: "{% error %}"
                      }
                    ]
                  }
                ]}
    end
  end

  describe "render!/3" do
    test "text rendering" do
      template = "simple text"

      assert template
             |> Solid.parse!()
             |> Solid.render!(%{})
             |> IO.iodata_to_binary() == "simple text"
    end

    test "object rendering" do
      template = "{{ var1 | upcase }}"

      assert template
             |> Solid.parse!()
             |> Solid.render!(%{"var1" => "yo"})
             |> IO.iodata_to_binary() == "YO"
    end

    test "empty object rendering" do
      template = "{{}}"

      assert template
             |> Solid.parse!()
             |> Solid.render!(%{})
             |> IO.iodata_to_binary() == ""
    end

    test "echo tag rendering" do
      template = "{% echo 'yo' %}"

      assert template
             |> Solid.parse!()
             |> Solid.render!(%{})
             |> IO.iodata_to_binary() == "yo"
    end

    test "assign tag rendering" do
      template = "{%- assign var1 = 'yo' -%} {{- var1 -}}"

      assert template
             |> Solid.parse!()
             |> Solid.render!(%{})
             |> IO.iodata_to_binary() == "yo"
    end

    test "custom tag get_current_year rendering" do
      template = "{% get_current_year %}"

      tags =
        Solid.Tag.default_tags()
        |> Map.put("get_current_year", CustomTags.CurrentYear)

      assert template
             |> Solid.parse!(tags: tags)
             |> Solid.render!(%{})
             |> IO.iodata_to_binary() == to_string(Date.utc_today().year)
    end

    test "custom tag myblock rendering" do
      template = """
      {%- myblock -%}
        {%- echo 'yo' -%}
        {%- assign var1 = "foo" -%}
        {{- var1 -}}
      {%- endmyblock -%}
      """

      tags =
        Solid.Tag.default_tags()
        |> Map.put("myblock", CustomTags.CustomBrackedWrappedTag)

      assert template
             |> Solid.parse!(tags: tags)
             |> Solid.render!(%{})
             |> IO.iodata_to_binary() == "yofoo"
    end

    test "protcol not implemented for structs" do
      template = "{{ var1 }}"

      assert_raise(Protocol.UndefinedError, fn ->
        template
        |> Solid.parse!()
        |> Solid.render!(%{__struct__: MyStruct, var1: "yo"})
      end)
    end

    test "protcol not implemented for floats" do
      template = "{{ var1 }}"

      assert_raise(Protocol.UndefinedError, fn ->
        template
        |> Solid.parse!()
        |> Solid.render!(3.14)
      end)
    end
  end

  describe "strict_variables" do
    test "object rendering" do
      template = "a{{ var1 }} {{ var2 }}b"

      {:error, error, partial_result} =
        template
        |> Solid.parse!()
        |> Solid.render(%{}, strict_variables: true)

      assert IO.iodata_to_binary(partial_result) == "a b"

      assert error == [
               %Solid.UndefinedVariableError{
                 variable: ["var1"],
                 original_name: "var1",
                 loc: %Solid.Parser.Loc{line: 1, column: 5}
               },
               %Solid.UndefinedVariableError{
                 variable: ["var2"],
                 original_name: "var2",
                 loc: %Solid.Parser.Loc{line: 1, column: 16}
               }
             ]
    end

    test "render tag no file system" do
      template = "a{{ var1 }} {{ var2 }}b {% render 'filesystem not configured' %}c"

      {:ok, partial_result, errors} =
        template
        |> Solid.parse!()
        |> Solid.render(%{})

      assert IO.iodata_to_binary(partial_result) ==
               "a b This liquid context does not allow includes.c"

      assert errors == [
               %Solid.FileSystem.Error{
                 loc: %Solid.Parser.Loc{line: 1, column: 25},
                 reason: "This solid context does not allow includes."
               }
             ]
    end

    test "inner rendering" do
      template = "a{{ var1 }} {{ var2 }}b {% render 'missing_var' %}c"

      {:error, error, partial_result} =
        template
        |> Solid.parse!()
        |> Solid.render(%{}, strict_variables: true, file_system: {TestFileSystem, nil})

      assert IO.iodata_to_binary(partial_result) == "a b c"

      assert error == [
               %Solid.UndefinedVariableError{
                 variable: ["var1"],
                 original_name: "var1",
                 loc: %Solid.Parser.Loc{line: 1, column: 5}
               },
               %Solid.UndefinedVariableError{
                 variable: ["var2"],
                 original_name: "var2",
                 loc: %Solid.Parser.Loc{line: 1, column: 16}
               },
               # FIXME this should somehow point out which file?
               # Check how liquid does this
               %Solid.UndefinedVariableError{
                 variable: ["var3"],
                 original_name: "var3",
                 loc: %Solid.Parser.Loc{line: 1, column: 4}
               }
             ]
    end

    test "return errors when both strict_variables and strict_filters are on" do
      template = "a{{ var1 | non_existing_filter }} {{ var2 | capitalize }}b"

      {:error, error, partial_result} =
        template
        |> Solid.parse!()
        |> Solid.render(%{}, strict_filters: true)

      assert IO.iodata_to_binary(partial_result) == "a b"

      assert error == [
               %Solid.UndefinedFilterError{
                 loc: %Solid.Parser.Loc{column: 12, line: 1},
                 filter: "non_existing_filter"
               }
             ]

      {:error, error, partial_result} =
        template
        |> Solid.parse!()
        |> Solid.render(%{}, strict_variables: true, strict_filters: true)

      assert IO.iodata_to_binary(partial_result) == "a b"

      assert error == [
               %Solid.UndefinedVariableError{
                 variable: ["var1"],
                 original_name: "var1",
                 loc: %Solid.Parser.Loc{line: 1, column: 5}
               },
               %Solid.UndefinedFilterError{
                 loc: %Solid.Parser.Loc{column: 12, line: 1},
                 filter: "non_existing_filter"
               },
               %Solid.UndefinedVariableError{
                 variable: ["var2"],
                 original_name: "var2",
                 loc: %Solid.Parser.Loc{line: 1, column: 38}
               }
             ]
    end

    test "undefined variable error message with multiple variables" do
      template =
        "{{ var1 }}\n{{ event.name }}\n{{ user.properties['name'] }}\n"

      {:error, [first_error, second_error, third_error], _partial_result} =
        template
        |> Solid.parse!()
        |> Solid.render(%{}, strict_variables: true, file_system: {TestFileSystem, nil})

      assert String.contains?(Solid.UndefinedVariableError.message(first_error), "var1")

      assert String.contains?(
               Solid.UndefinedVariableError.message(second_error),
               "event.name"
             )

      assert String.contains?(
               Solid.UndefinedVariableError.message(third_error),
               "user.properties['name']"
             )
    end

    test "undefined filter error message with line number" do
      template = "{{ var1 | not_a_filter }}"

      assert_raise Solid.RenderError,
                   "1 error(s) found while rendering\n1: Undefined filter not_a_filter",
                   fn ->
                     template
                     |> Solid.parse!()
                     |> Solid.render!(%{"var1" => "value"},
                       strict_filters: true,
                       file_system: {TestFileSystem, nil}
                     )
                   end
    end
  end
end
