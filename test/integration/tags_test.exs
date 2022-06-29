defmodule Solid.Integration.TagsTest do
  use ExUnit.Case, async: true
  import Solid.Helpers

  describe "if" do
    test "true expression" do
      assert render("{% if 1 == 1 %}True{% endif %} is True", %{"key" => 123}) == "True is True"
      assert_no_errors!()
    end

    test "false expression" do
      assert render("{% if 1 != 1 %}True{% endif %}False?", %{"key" => 123}) == "False?"
      assert_no_errors!()
    end

    test "true" do
      assert render("{% if true %}True{% endif %} is True", %{"key" => 123}) == "True is True"
      assert_no_errors!()
    end

    test "false" do
      assert render("{% if false %}True{% endif %}False?", %{"key" => 123}) == "False?"
      assert_no_errors!()
    end

    test "boolean expression" do
      assert render("{% if 1 != 1 or 3 == 3 %}True{% endif %}", %{"key" => 123}) == "True"
      assert_no_errors!()
    end

    test "nested" do
      assert render("{% if 1 == 1 %}{% if 1 != 2 %}True{% endif %}{% endif %} is True", %{
               "key" => 123
             }) == "True is True"

      assert_no_errors!()
    end

    test "with object" do
      assert render("{% if 1 != 2 %}{{ key }}{% endif %}", %{"key" => 123}) == "123"

      assert_no_errors!()
    end

    test "else true" do
      assert render("{% if 1 == 1 %}True{% else %}False{% endif %} is True", %{"key" => 123}) ==
               "True is True"

      assert_no_errors!()
    end

    test "else false" do
      assert render("{% if 1 != 1 %}True{% else %}False{% endif %} is False", %{"key" => 123}) ==
               "False is False"

      assert_no_errors!()
    end

    test "elsif" do
      assert render("{% if 1 != 1 %}if{% elsif 1 == 1 %}elsif{% endif %}") == "elsif"
      assert_no_errors!()
    end
  end

  describe "unless" do
    test "true expression" do
      assert render("{% unless 1 == 1 %}True{% endunless %}False?", %{"key" => 123}) == "False?"
      assert_no_errors!()
    end

    test "false expression" do
      assert render("{% unless 1 != 1 %}True{% endunless %} is True", %{"key" => 123}) ==
               "True is True"

      assert_no_errors!()
    end

    test "true" do
      assert render("{% unless true %}False{% endunless %}False?", %{"key" => 123}) == "False?"
      assert_no_errors!()
    end

    test "false" do
      assert render("{% unless false %}True{% endunless %} is True", %{"key" => 123}) ==
               "True is True"

      assert_no_errors!()
    end

    test "nested" do
      assert render(
               "{% unless 1 != 1 %}{% unless 1 == 2 %}True{% endunless %}{% endunless %} is True",
               %{"key" => 123}
             ) == "True is True"

      assert_no_errors!()
    end

    test "with object" do
      assert render("{% unless 1 == 2 %}{{ key }}{% endunless %}", %{"key" => 123}) == "123"
      assert_no_errors!()
    end

    test "elsif" do
      assert render("{% unless 1 == 1 %}unless{% elsif 1 == 1 %}elsif{% endunless %}") == "elsif"
      assert_no_errors!()
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

      assert Solid.ErrorContext.get() == %Solid.ErrorContext{
               errors: [
                 %Solid.ErrorContext.UndefinedVariable{variable: "handle"}
               ],
               warnings: []
             }
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
      assert_no_errors!()
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
      assert_no_errors!()
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
      assert_no_errors!()
    end

    test "for using range literals" do
      text = """
      {% for value in (1..2) %}
        Got: {{ value }}
      {% endfor %}
      """

      assert render(text, %{}) == "\n  Got: 1\n\n  Got: 2\n\n"
      assert_no_errors!()
    end

    test "for using range variables" do
      text = """
      {% for value in (first..last) %}
        Got: {{ value }}
      {% endfor %}
      """

      assert render(text, %{"first" => 1, "last" => 2}) == "\n  Got: 1\n\n  Got: 2\n\n"
      assert_no_errors!()
    end

    test "simple for with a break" do
      text = """
      {% for value in values %}
      {% if value == 2 %}{% break %}{% endif %} Got: {{ value }}
      {% endfor %}
      """

      assert render(text, %{"values" => [1, 2]}) == "\n Got: 1\n\n\n"
      assert_no_errors!()
    end

    test "with conditional tag" do
      text = """
      {% for value in values %}
        {% if value > 2 %}I got {{ value }}!{% endif %}
      {% endfor %}
      """

      assert render(text, %{"values" => [1, 2, 3]}) == "\n  \n\n  \n\n  I got 3!\n\n"
      assert_no_errors!()
    end

    test "with no value" do
      text = "test {% for value in values %}{{ value }}{% endfor %}"
      assert render(text, %{}) == "test "

      assert Solid.ErrorContext.get() == %Solid.ErrorContext{
               errors: [
                 %Solid.ErrorContext.UndefinedVariable{variable: "values"}
               ],
               warnings: []
             }
    end

    test "with no value and an else" do
      text = """
      test {% for value in values %}
        {{ value }}
      {% else %}
      else
      {% endfor %}
      """

      assert render(text, %{"values" => []}) == "test \nelse\n\n"
      assert_no_errors!()
    end

    test "with no variable and an else" do
      text = """
      test {% for value in values %}
        {{ value }}
      {% else %}
      else
      {% endfor %}
      """

      assert render(text, %{}) == "test \nelse\n\n"

      assert Solid.ErrorContext.get() == %Solid.ErrorContext{
               errors: [
                 %Solid.ErrorContext.UndefinedVariable{variable: "values"}
               ],
               warnings: []
             }
    end
  end

  describe "assign" do
    test "assign literal value" do
      text = """
      {% assign variable = 1 %}
      Variable: {{ variable }}
      """

      assert render(text, %{}) == "\nVariable: 1\n"
      assert_no_errors!()
    end

    test "assign to empty" do
      text = """
      {% assign variable = "" %}
      Variable: {{ variable }}
      """

      assert render(text, %{"variable" => 1}) == "\nVariable: \n"

      assert Solid.ErrorContext.get() == %Solid.ErrorContext{
               errors: [],
               warnings: [
                 %Solid.ErrorContext.EmptyWarning{filter: [], variable: "variable"}
               ]
             }
    end

    test "assign existing variable" do
      text = """
      {% assign variable = existing %}
      Variable: {{ variable }}
      """

      assert render(text, %{"existing" => 123}) == """

             Variable: 123
             """

      assert_no_errors!()
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

      assert_no_errors!()
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

      assert_no_errors!()
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

      assert_no_errors!()
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

      assert_no_errors!()
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

      assert_no_errors!()
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

      assert_no_errors!()
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

      assert_no_errors!()
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

      assert_no_errors!()
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

      assert_no_errors!()
    end

    test "with an argument" do
      text = """
      {% foobarval "-show-me" %}
      """

      assert render(text, %{}, parser: CustomFooParser) ==
               """
               barbaz-show-me
               """

      assert_no_errors!()
    end
  end
end
