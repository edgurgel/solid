defmodule SolidTest do
  use ExUnit.Case, async: true
  alias Solid.ParserError

  defmodule TestFileSystem do
    @behaviour Solid.FileSystem

    @impl true
    def read_template_file("error", _opts), do: {:ok, "{% error %}"}
    def read_template_file("missing_var", _opts), do: {:ok, "{{ var3 }}"}
    def read_template_file("size_args", _opts), do: {:ok, "[{{ size }}|{{ first }}]"}
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
                            access_type: :dot,
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

  defmodule DelegatingMatcher do
    def match(data, keys), do: Solid.Matcher.match(data, keys)
  end

  defmodule AtomKeysMatcher do
    def match(data, []), do: {:ok, data}

    def match(data, [key | keys]) when is_map(data) and is_binary(key) do
      case Map.fetch(data, String.to_atom(key)) do
        {:ok, value} -> match(value, keys)
        :error -> Solid.Matcher.match(data, [key | keys])
      end
    end

    def match(data, keys), do: Solid.Matcher.match(data, keys)
  end

  defmodule GlobalsMatcher do
    def match(data, ["today"]) when not is_map_key(data, "today"), do: {:ok, "2026-11-15"}
    def match(data, keys), do: Solid.Matcher.match(data, keys)
  end

  defmodule LazyData do
    defstruct [:loader]
  end

  defmodule LazyMatcher do
    def match(%LazyData{loader: loader}, [key | keys]),
      do: Solid.Matcher.match(loader.(key), keys)

    def match(data, keys), do: Solid.Matcher.match(data, keys)
  end

  defmodule AnswerEverythingMatcher do
    def match(_data, _keys), do: {:ok, 42}
  end

  describe "matcher_module" do
    defp render_with(template, data, matcher) do
      template
      |> Solid.parse!()
      |> Solid.render!(data,
        matcher_module: matcher,
        file_system: {TestFileSystem, nil}
      )
      |> IO.iodata_to_binary()
    end

    test "size and first as variable names with a matcher delegating to Solid.Matcher" do
      template = """
      {%- assign size = "big" -%}
      {{ size }}|{{ first }}|{% for x in (1..2) %}{{ size }}{{ first }}{% endfor %}|{{ h.size }}
      """

      assert render_with(template, %{"first" => "one", "h" => %{"a" => 1}}, DelegatingMatcher) ==
               "big|one|bigonebigone|1\n"
    end

    test "size and first as render arguments with a matcher delegating to Solid.Matcher" do
      template = ~S({% render "size_args", size: "big", first: "one" %})
      assert render_with(template, %{}, DelegatingMatcher) == "[big|one]"
    end

    test "undefined size and first with a matcher that looks up the root name itself" do
      template =
        ~S'[{{ size }}|{{ first }}|{% for x in (1..2) %}{{ size }}{{ first }}{% endfor %}]' <>
          ~S({% render "size_args" %})

      assert render_with(template, %{"x" => 1}, Solid.RootLookupMatcher) == "[||][|]"
    end

    test "increment and decrement on undefined size and first" do
      template =
        ~S({% increment size %}{% increment size %}{% decrement first %}|{{ size }}|{{ first }})

      for matcher <- [Solid.Matcher, Solid.RootLookupMatcher] do
        assert render_with(template, %{"a" => 1, "b" => 2}, matcher) == "01-1|2|-1"
      end
    end

    test "increment starts from a size or first defined in the render data" do
      template = ~S({% increment size %}{% decrement first %}|{{ size }}|{{ first }})

      assert render_with(template, %{"size" => 5, "first" => 7}, DelegatingMatcher) ==
               "56|6|6"
    end

    test "undefined size reports an undefined variable with strict_variables" do
      {:error, errors, result} =
        "{{ size }}"
        |> Solid.parse!()
        |> Solid.render(%{}, matcher_module: Solid.RootLookupMatcher, strict_variables: true)

      assert IO.iodata_to_binary(result) == ""
      assert [%Solid.UndefinedVariableError{variable: ["size"]}] = errors
    end

    test "render data with atom keys" do
      data = %{name: "Ann", user: %{email: "a@x"}, size: "big", first: "one"}

      assert render_with(
               "{{ name }}|{{ user.email }}|{{ size }}|{{ first }}",
               data,
               AtomKeysMatcher
             ) ==
               "Ann|a@x|big|one"
    end

    test "size and first assigned or looped over with atom keys in render data" do
      template =
        ~S'{% assign size = "s" %}{{ size }}|{% for first in (1..2) %}{{ size }}{{ first }}{% endfor %}|{{ first }}'

      assert render_with(template, %{first: "one"}, AtomKeysMatcher) == "s|s1s2|one"
    end

    test "a matcher answering for a name missing from the render data" do
      assert render_with("{{ today }}|{{ number }}", %{"number" => 4}, GlobalsMatcher) ==
               "2026-11-15|4"

      assert render_with("{{ number }}|{{ missing }}", %{"number" => 4}, AnswerEverythingMatcher) ==
               "42|42"
    end

    test "render data that is not a plain map is resolved by the matcher" do
      data = %LazyData{
        loader: fn
          "user" -> %{"name" => "Ed"}
          _ -> nil
        end
      }

      template = ~S({% assign size = "big" %}{{ user.name }}|{{ size }}|{{ missing }})

      assert render_with(template, data, LazyMatcher) == "Ed|big|"
    end
  end
end
