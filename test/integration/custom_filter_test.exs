defmodule Solid.Integration.CustomFiltersTest do
  use ExUnit.Case, async: true
  import Solid.Helpers

  defmodule Solid.CustomFilters do
    def date_year(input) do
      date = Date.from_iso8601!(input)
      date.year
    end

    def date_format(input, format) when is_binary(input),
      do: input |> Date.from_iso8601!() |> date_format(format)

    def date_format(date, "m/d/yyyy"),
      do: Enum.join([date.month, date.day, date.year], "/")

    def date_format(date, "d.m.yyyy"),
      do: Enum.join([date.day, date.month, date.year], ".")

    def date_format(date, _format),
      do: to_string(date)

    def substitute(message, bindings \\ %{}) do
      Regex.replace(~r/%\{(\w+)\}/, message, fn _, key -> Map.get(bindings, key) end)
    end

    def asset_url(input, opts) do
      url = Keyword.get(opts, :"#{input}", "")
      url <> input
    end
  end

  setup do
    Application.put_env(:solid, :custom_filters, Solid.CustomFilters)
    {:ok, %{date: "2019-10-31"}}
  end

  describe "custom filters" do
    test "date year filter", %{date: date} do
      assert render("{{ date_var | date_year }}", %{"date_var" => date}) == "2019"
    end

    test "date format m/d/yyyy", %{date: date} do
      assert render(~s<{{ date_var | date_format: "m/d/yyyy" }}>, %{"date_var" => date}) ==
               "10/31/2019"
    end

    test "date format d.m.yyyy", %{date: date} do
      assert render(~s<{{ date_var | date_format: "d.m.yyyy" }}>, %{"date_var" => date}) ==
               "31.10.2019"
    end

    test "date format with malformed format", %{date: date} do
      assert render(~s<{{ date_var | date_format: "x/y/z" }}>, %{"date_var" => date}) ==
               "2019-10-31"
    end

    test "substitute without bindings" do
      assert render(~s<{{ "hello world" | substitute }}>)
    end

    test "substitute with bindings", %{date: date} do
      assert render(~s<{{ "today is %{today}" | substitute: today: date_var }}>, %{
               "date_var" => date
             }) ==
               "today is 2019-10-31"
    end

    test "asset_url with opts" do
      assert render(~s<{{ "app.css" | asset_url }}>, %{}, "app.css": "http://assets.example.com/") ==
               "http://assets.example.com/app.css"
    end

    defmodule MyCustomFilters do
      def add_one(x), do: x + 1
    end

    test "custom filters from render options" do
      opts = [custom_filters: MyCustomFilters]
      assert render("{{ number | add_one }}", %{"number" => 2}, opts) == "3"
    end
  end
end
