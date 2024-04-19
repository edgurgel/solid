defmodule Solid.Integration.TagsTest do
  use ExUnit.Case, async: true
  import Solid.Helpers
  alias Solid.UndefinedVariableError

  describe "if" do
    test "true expression" do
      assert render("{% if 1 == 1 %}True{% endif %} is True", %{"key" => 123}) == "True is True"
    end

    test "false expression" do
      assert render("{% if 1 != 1 %}True{% endif %}False?", %{"key" => 123}) == "False?"
    end

    test "if expression with strict_variables" do
      assert render("{% if other_key == nil %}True{% endif %} is True", %{"key" => 123},
               strict_variables: true
             ) ==
               {:error, [%UndefinedVariableError{variable: ["other_key"]}], "True is True"}
    end

    test "true" do
      assert render("{% if true %}True{% endif %} is True", %{"key" => 123}) == "True is True"
    end

    test "false" do
      assert render("{% if false %}True{% endif %}False?", %{"key" => 123}) == "False?"
    end

    test "boolean expression" do
      assert render("{% if 1 != 1 or 3 == 3 %}True{% endif %}", %{"key" => 123}) == "True"
    end

    test "nested" do
      assert render("{% if 1 == 1 %}{% if 1 != 2 %}True{% endif %}{% endif %} is True", %{
               "key" => 123
             }) == "True is True"
    end

    test "nested if with strict_variables" do
      assert render(
               "{% if 1 == 1 %}{% if other_key != 2 %}True{% endif %}{% endif %} is True",
               %{"key" => 123},
               strict_variables: true
             ) ==
               {:error, [%UndefinedVariableError{variable: ["other_key"]}], "True is True"}
    end

    test "with object" do
      assert render("{% if 1 != 2 %}{{ key }}{% endif %}", %{"key" => 123}) == "123"
    end

    test "else true" do
      assert render("{% if 1 == 1 %}True{% else %}False{% endif %} is True", %{"key" => 123}) ==
               "True is True"
    end

    test "else false" do
      assert render("{% if 1 != 1 %}True{% else %}False{% endif %} is False", %{"key" => 123}) ==
               "False is False"
    end

    test "elsif" do
      assert render("{% if 1 != 1 %}if{% elsif 1 == 1 %}elsif{% endif %}") == "elsif"
    end

    test "elsif strict_variables" do
      assert render("{% if 1 != 1 %}if{% elsif other_key != 1 %}elsif{% endif %}", %{},
               strict_variables: true
             ) == {:error, [%UndefinedVariableError{variable: ["other_key"]}], "elsif"}
    end
  end

  describe "unless" do
    test "true expression" do
      assert render("{% unless 1 == 1 %}True{% endunless %}False?", %{"key" => 123}) == "False?"
    end

    test "false expression" do
      assert render("{% unless 1 != 1 %}True{% endunless %} is True", %{"key" => 123}) ==
               "True is True"
    end

    test "unless expression with strict_variables" do
      assert render("{% unless other_key != nil %}True{% endunless %} is True", %{"key" => 123},
               strict_variables: true
             ) ==
               {:error, [%UndefinedVariableError{variable: ["other_key"]}], "True is True"}
    end

    test "true" do
      assert render("{% unless true %}False{% endunless %}False?", %{"key" => 123}) == "False?"
    end

    test "false" do
      assert render("{% unless false %}True{% endunless %} is True", %{"key" => 123}) ==
               "True is True"
    end

    test "nested" do
      assert render(
               "{% unless 1 != 1 %}{% unless 1 == 2 %}True{% endunless %}{% endunless %} is True",
               %{"key" => 123}
             ) == "True is True"
    end

    test "nested unless with strict_variables" do
      assert render(
               "{% unless 1 != 1 %}{% unless other_key == 2 %}True{% endunless %}{% endunless %} is True",
               %{"key" => 123},
               strict_variables: true
             ) ==
               {:error, [%UndefinedVariableError{variable: ["other_key"]}], "True is True"}
    end

    test "with object" do
      assert render("{% unless 1 == 2 %}{{ key }}{% endunless %}", %{"key" => 123}) == "123"
    end

    test "elsif" do
      assert render("{% unless 1 == 1 %}unless{% elsif 1 == 1 %}elsif{% endunless %}") == "elsif"
    end

    test "elsif strict_variables" do
      assert render(
               "{% unless 1 == 1 %}unless{% elsif other_key != 1 %}elsif{% endunless %}",
               %{},
               strict_variables: true
             ) == {:error, [%UndefinedVariableError{variable: ["other_key"]}], "elsif"}
    end
  end

  describe "case" do
    test "no matching when" do
      text = """
      {% case handle %}
      {% when 'cake' %}
      This is a cake
      {% endcase %}
      """

      assert render(text) == "\n"
    end

    test "no matching when with else" do
      text = """
      {% case handle %}
      {% when 'cake' %}
      This is a cake
      {% else %}
      Else
      {% endcase %}
      """

      assert render(text) == "\nElse\n\n"
    end

    test "with a matching when" do
      text = """
      {% case handle %}
      {% when 'not_cake' %}
      Not a cake
      {% when 'cake' %}
      This is a cake
      {% endcase %}
      """

      assert render(text, %{"handle" => "cake"}) == "\nThis is a cake\n\n"
    end

    test "no matching when strict_variables" do
      text = """
      {% case handle %}
      {% when 'cake' %}
      This is a cake
      {% endcase %}
      """

      assert {:error, errors, result} = render(text, %{}, strict_variables: true)
      assert errors == [%UndefinedVariableError{variable: ["handle"]}]
      assert result == "\n"
    end

    test "no matching when with else strict_variables" do
      text = """
      {% case handle %}
      {% when 'cake' %}
      This is a cake
      {% else %}
      Else
      {% endcase %}
      """

      assert {:error, errors, result} = render(text, %{}, strict_variables: true)
      assert errors == [%UndefinedVariableError{variable: ["handle"]}]
      assert result == "\nElse\n\n"
    end
  end

  describe "for" do
    test "for" do
      text = """
      {% for value in values %}
        Got: {{ value }}
      {% endfor %}
      """

      assert render(text, %{"values" => [1, 2]}) == "\n  Got: 1\n\n  Got: 2\n\n"
    end

    test "for using range literals" do
      text = """
      {% for value in (1..2) %}
        Got: {{ value }}
      {% endfor %}
      """

      assert render(text, %{}) == "\n  Got: 1\n\n  Got: 2\n\n"
    end

    test "for using range variables" do
      text = """
      {% for value in (first..last) %}
        Got: {{ value }}
      {% endfor %}
      """

      assert render(text, %{"first" => 1, "last" => 2}) == "\n  Got: 1\n\n  Got: 2\n\n"
    end

    test "simple for with a break" do
      text = """
      {% for value in values %}
      {% if value == 2 %}{% break %}{% endif %} Got: {{ value }}
      {% endfor %}
      """

      assert render(text, %{"values" => [1, 2]}) == "\n Got: 1\n\n\n"
    end

    test "with conditional tag" do
      text = """
      {% for value in values %}
        {% if value > 2 %}I got {{ value }}!{% endif %}
      {% endfor %}
      """

      assert render(text, %{"values" => [1, 2, 3]}) == "\n  \n\n  \n\n  I got 3!\n\n"
    end

    test "with no value" do
      text = "test {% for value in values %}{{ value }}{% endfor %}"
      assert render(text, %{}) == "test "
    end

    test "with no value and an else" do
      text = """
      test {% for value in values %}
        {{ value }}
      {% else %}
      else
      {% endfor %}
      """

      assert render(text, %{}) == "test \nelse\n\n"
    end

    test "for strict_variables" do
      text = """
      {% for value in values %}
        Got: {{ value }}{{variable1}}
      {% endfor %}
      """

      assert {:error, errors, result} =
               render(text, %{"values" => [1, 2]}, strict_variables: true)

      assert result == "\n  Got: 1\n\n  Got: 2\n\n"

      assert errors == [
               %UndefinedVariableError{variable: ["variable1"]},
               %UndefinedVariableError{variable: ["variable1"]}
             ]
    end
  end

  describe "assign" do
    test "assign literal value" do
      text = """
      {% assign variable = 1 %}
      Variable: {{ variable }}
      """

      assert render(text, %{}) == "\nVariable: 1\n"
    end

    test "assign existing variable" do
      text = """
      {% assign variable = existing %}
      Variable: {{ variable }}
      """

      assert render(text, %{"existing" => 123}) == """

             Variable: 123
             """
    end

    test "assign strict_variables" do
      text = """
      {% assign variable = missing %}
      Variable: {{ variable }}
      """

      assert {:error, errors, result} = render(text, %{}, strict_variables: true)
      assert errors == [%UndefinedVariableError{variable: ["missing"]}]
      assert result == "\nVariable: \n"
    end
  end

  describe "increment" do
    test "increment" do
      text = """
      {% increment counter %}
      counter value: {{ counter }}
      """

      assert render(text, %{}) == """
             0
             counter value: 1
             """
    end

    test "increment strict_variables" do
      text = """
      {% increment counter %}
      counter value: {{ counter }}
      """

      assert {:error, errors, result} = render(text, %{}, strict_variables: true)
      assert errors == [%UndefinedVariableError{variable: ["counter"]}]

      assert result == """
             0
             counter value: 1
             """
    end

    test "increment multiple calls" do
      text = """
      {% increment counter %}
      {% increment counter %}
      counter value: {{ counter }}
      """

      assert render(text, %{}) == """
             0
             1
             counter value: 2
             """
    end
  end

  describe "decrement" do
    test "decrement" do
      text = """
      {% decrement counter %}
      counter value: {{ counter }}
      """

      assert render(text, %{}) == """
             -1
             counter value: -2
             """
    end

    test "increment strict_variables" do
      text = """
      {% decrement counter %}
      counter value: {{ counter }}
      """

      assert {:error, errors, result} = render(text, %{}, strict_variables: true)
      assert errors == [%UndefinedVariableError{variable: ["counter"]}]

      assert result == """
             -1
             counter value: -2
             """
    end

    test "decrement multiple calls" do
      text = """
      {% decrement counter %}
      {% decrement counter %}
      counter value: {{ counter }}
      """

      assert render(text, %{}) == """
             -1
             -2
             counter value: -3
             """
    end
  end

  describe "capture" do
    test "capture" do
      text = """
      {% capture value %}
      the text is here
      {% endcapture %}
      Outside of capture

      {{ value }}
      """

      assert render(text, %{}) == """

             Outside of capture


             the text is here

             """
    end

    test "capture strict_variables" do
      text = """
      {% capture value %}
      the text is here{{ variable1 }}
      {% endcapture %}
      Outside of capture

      {{ value }}{{ variable2 }}
      """

      assert {:error, errors, result} = render(text, %{}, strict_variables: true)

      assert errors == [
               %UndefinedVariableError{variable: ["variable1"]},
               %UndefinedVariableError{variable: ["variable2"]}
             ]

      assert assert result == """

                    Outside of capture


                    the text is here

                    """
    end
  end

  describe "break" do
    test "break" do
      text = """
      pre-break
      {% break %}
      post-break
      """

      assert render(text, %{}) == """
             pre-break
             """
    end

    test "break strict_variables" do
      text = """
      pre-break
      {{ variable1 }}
      {% break %}
      {{ variable2 }}
      post-break
      """

      assert {:error, errors, result} = render(text, %{}, strict_variables: true)

      assert errors == [%UndefinedVariableError{variable: ["variable1"]}]

      assert result == """
             pre-break

             """
    end
  end

  describe "continue" do
    test "continue" do
      text = """
      pre-continue
      {% continue %}
      post-continue
      """

      assert render(text, %{}) == """
             pre-continue
             """
    end

    test "continue strict_variables" do
      text = """
      pre-continue
      {{ variable1 }}
      {% continue %}
      {{ variable2 }}
      post-continue
      """

      assert {:error, errors, result} = render(text, %{}, strict_variables: true)

      assert errors == [%UndefinedVariableError{variable: ["variable1"]}]

      assert result == """
             pre-continue

             """
    end
  end

  describe "raw" do
    test "simple raw" do
      text = """
      {% raw %}{{ 5 | plus: 6 }}{% endraw %} equals {{ 5 | plus: 6 }}
      """

      assert render(text, %{}) == """
             {{ 5 | plus: 6 }} equals 11
             """
    end

    test "raw with nested tag" do
      text = """
      {% raw %}{% increment counter %}{{ counter }}{% endraw %}
      {% increment counter %} {{ counter }}
      """

      assert render(text, %{}) == """
             {% increment counter %}{{ counter }}
             0 1
             """
    end
  end

  describe "custom tag" do
    test "with no arguments" do
      text = """
      {% foobar %}
      """

      assert render(text, %{}, parser: CustomFooParser) ==
               """
               barbaz
               """
    end

    test "with an argument" do
      text = """
      {% foobarval "-show-me" %}
      """

      assert render(text, %{}, parser: CustomFooParser) ==
               """
               barbaz-show-me
               """
    end
  end

  describe "excluded standard tag" do
    test "a standard tag can be removed from the parser" do
      text = """
      test: {% render "nope" %}
      """

      assert {:ok, _} = Solid.parse(text)

      assert {:error, %Solid.TemplateError{line: {1, 0}}} =
               Solid.parse(text, parser: NoRenderParser)
    end
  end

  defmodule FakeFileSystem do
    def read_template_file("file1", _opts) do
      "{{ name }}{{ variable1 }}{{ variable2 }}"
    end
  end

  describe "render" do
    test "variable scope is respected" do
      text = """
      template:
      {% render "file1", name: "abc" %}
      {{ variable1 }}
      {{ variable2 }}
      end
      """

      assert render(text, %{"variable1" => "123"}, file_system: {FakeFileSystem, []}) == """
             template:
             abc
             123

             end
             """
    end

    test "strict_variables" do
      text = """
      template:
      {% render "file1", name: "abc" %}
      {{ variable1 }}
      {{ variable3 }}
      end
      """

      assert {:error, errors, result} =
               render(text, %{"variable1" => "123"},
                 file_system: {FakeFileSystem, []},
                 strict_variables: true
               )

      assert errors == [
               %UndefinedVariableError{variable: ["variable1"]},
               %UndefinedVariableError{variable: ["variable2"]},
               %UndefinedVariableError{variable: ["variable3"]}
             ]

      assert result == """
             template:
             abc
             123

             end
             """
    end
  end
end
