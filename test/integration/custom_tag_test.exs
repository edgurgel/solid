defmodule Solid.Integration.CustomTagsTest do
  use ExUnit.Case, async: true
  import Solid.Helpers

  describe "custom tags" do
    test "pass in custom tag that needs no arguments" do
      assert render("{% current_date %}", %{},
               tags: %{"current_date" => CustomTags.CurrentDate},
               parser: CustomDateParser
             ) ==
               to_string(DateTime.utc_now().year)
    end

    test "pass in custom tag that needs arguments" do
      assert render(~s({% get_year_of_date "2020-08-06T06:23:48Z" %}), %{},
               tags: %{"get_year_of_date" => CustomTags.GetYearOfDate},
               parser: CustomDateParser
             ) ==
               "2020-8-6"
    end

    test "custom tags are evaluated inside of for loops" do
      assert render(
               "{% for date in dates %}<span>{% get_year_of_date date %}</span>{% endfor %}",
               %{"dates" => ["2020-08-06T06:23:48Z", "2021-05-03T06:23:48Z"]},
               tags: %{"get_year_of_date" => CustomTags.GetYearOfDate},
               parser: CustomDateParser
             ) == "<span>2020-8-6</span><span>2021-5-3</span>"
    end

    test "custom tags are evaluated inside of captures" do
      assert render(
               ~s({% capture testing %}{% get_year_of_date "2020-08-06T06:23:48Z" %}{% endcapture %}{{ testing }}),
               %{"dates" => ["2020-08-06T06:23:48Z", "2021-05-03T06:23:48Z"]},
               tags: %{"get_year_of_date" => CustomTags.GetYearOfDate},
               parser: CustomDateParser
             ) == "2020-8-6"
    end

    test "custom tags are evaluated inside of for loops and captures" do
      rendered =
        render(
          """
          {% capture testing %}
            {% for date in dates %}<span>{% get_year_of_date date %}</span>{% endfor %}
          {% endcapture %}

          {{ testing }}
          """,
          %{"dates" => ["2020-08-06T06:23:48Z", "2021-05-03T06:23:48Z"]},
          tags: %{"get_year_of_date" => CustomTags.GetYearOfDate},
          parser: CustomDateParser
        )

      assert String.trim(rendered) == "<span>2020-8-6</span><span>2021-5-3</span>"
    end
  end

  describe "custom tags modules" do
    test "pass in custom tag that needs no arguments" do
      assert render("{% get_current_date %}", %{},
               tags: %{"get_current_date" => CustomTags.CurrentDate},
               parser: CustomDateParser
             ) ==
               to_string(DateTime.utc_now().year)
    end

    test "pass in custom tag that needs arguments" do
      assert render(~s({% get_year "2020-08-06T06:23:48Z" %}), %{},
               tags: %{"get_year" => CustomTags.GetYearOfDate},
               parser: CustomDateParser
             ) ==
               "2020-8-6"
    end

    test "custom tags are evaluated inside of for loops" do
      assert render(
               "{% for date in dates %}<span>{% get_year date %}</span>{% endfor %}",
               %{"dates" => ["2020-08-06T06:23:48Z", "2021-05-03T06:23:48Z"]},
               tags: %{"get_year" => CustomTags.GetYearOfDate},
               parser: CustomDateParser
             ) == "<span>2020-8-6</span><span>2021-5-3</span>"
    end

    test "custom tags are evaluated inside of captures" do
      assert render(
               ~s({% capture testing %}{% get_year "2020-08-06T06:23:48Z" %}{% endcapture %}{{ testing }}),
               %{"dates" => ["2020-08-06T06:23:48Z", "2021-05-03T06:23:48Z"]},
               tags: %{"get_year" => CustomTags.GetYearOfDate},
               parser: CustomDateParser
             ) == "2020-8-6"
    end

    test "custom tags are evaluated inside of for loops and captures" do
      rendered =
        render(
          """
          {% capture testing %}
            {% for date in dates %}<span>{% get_year date %}</span>{% endfor %}
          {% endcapture %}

          {{ testing }}
          """,
          %{"dates" => ["2020-08-06T06:23:48Z", "2021-05-03T06:23:48Z"]},
          tags: %{"get_year" => CustomTags.GetYearOfDate},
          parser: CustomDateParser
        )

      assert String.trim(rendered) == "<span>2020-8-6</span><span>2021-5-3</span>"
    end
  end
end
