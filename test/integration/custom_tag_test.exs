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
    end
  end

  describe "custom tags" do
    test "pass in custom tag that needs no arguments" do
      assert render("{% current_date %}", %{}, tags: %{"current_date" => CustomTags.CurrentDate}) ==
               "2020"
    end

    test "pass in custom tag that needs arguments" do
      assert render(~s({% get_year_of_date "2020-08-06T06:23:48Z" %}), %{},
               tags: %{"get_year_of_date" => CustomTags.GetYearOfDate}
             ) ==
               "2020-8-6"
    end
  end
end
