defmodule Solid.Integration.CustomTagsTest do
  use ExUnit.Case, async: true
  import Solid.Helpers

  defmodule CustomTags do
    defmodule CurrentDate do
      def render(_context, _arguments) do
        DateTime.utc_now().year |> to_string
      end
    end

    defmodule GetYearOfDate do
      def render(_context, arguments: [value: dt_str]) do
        {:ok, dt, _} = DateTime.from_iso8601(dt_str)
        "#{dt.year}-#{dt.month}-#{dt.day}"
      end

      def render(context, arguments: [field: [var_name]]) do
        dt_str = Map.fetch!(context.iteration_vars, var_name)
        {:ok, dt, _} = DateTime.from_iso8601(dt_str)
        "#{dt.year}-#{dt.month}-#{dt.day}"
      end
    end

    defmodule PaddingText do
      def render(context, arguments: [value: text, value: pad_str, named_arguments: args]) do
        %{"times" => time} = parse_named_arguments(args, context)
        "#{text}#{String.duplicate(pad_str, time)}"
      end

      defp parse_named_arguments(ast, context) do
        ast
        |> Enum.chunk_every(2)
        |> Map.new(fn [key, value_or_field] ->
          {key, Solid.Argument.get([value_or_field], context)}
        end)
      end
    end
  end

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

    test "custom tag with mix positional and named argument" do
      rendered =
        render(
          "{% pad 'its so c', 'o', times: count %}",
          %{"count" => 10},
          tags: %{"pad" => CustomTags.PaddingText},
          parser: CustomPaddingParser
        )

      assert String.trim(rendered) == "its so coooooooooo"
    end
  end
end
