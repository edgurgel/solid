defmodule Solid.Integration.CustomFiltersTest do
  use ExUnit.Case, async: false
  import Solid.Helpers

  setup do
    opts = [custom_filters: Solid.CustomFilters]
    {:ok, date: "2019-10-31", opts: opts}
  end

  describe "custom filters" do
    test "date year filter", %{opts: opts, date: date} do
      assert render("{{ date_var | date_year }}", %{"date_var" => date}, opts) == "2019"
    end

    test "date format m/d/yyyy", %{opts: opts, date: date} do
      assert render(~s<{{ date_var | date_format: "m/d/yyyy" }}>, %{"date_var" => date}, opts) ==
               "10/31/2019"
    end

    test "date format d.m.yyyy", %{opts: opts, date: date} do
      assert render(~s<{{ date_var | date_format: "d.m.yyyy" }}>, %{"date_var" => date}, opts) ==
               "31.10.2019"
    end

    test "date format with malformed format", %{opts: opts, date: date} do
      assert render(~s<{{ date_var | date_format: "x/y/z" }}>, %{"date_var" => date}, opts) ==
               "2019-10-31"
    end

    test "substitute without bindings" do
      opts = [custom_filters: Solid.CustomFilters]
      assert render(~s<{{ "hello world" | substitute }}>, %{}, opts)
    end

    test "substitute with bindings", %{opts: opts, date: date} do
      assert render(
               ~s<{{ "today is %{today}" | substitute: today: date_var }}>,
               %{"date_var" => date},
               opts
             ) ==
               "today is 2019-10-31"
    end

    test "asset_url with opts" do
      opts = [custom_filters: Solid.CustomFilters, "app.css": "http://assets.example.com/"]

      assert render(~s<{{ "app.css" | asset_url }}>, %{}, opts) ==
               "http://assets.example.com/app.css"
    end

    defmodule MyCustomFilters do
      def add_one(x), do: x + 1
    end

    test "custom filters from global options" do
      Application.put_env(:solid, :custom_filters, MyCustomFilters)
      on_exit(fn -> Application.delete_env(:solid, :custom_filters) end)
      assert render("{{ number | add_one }}", %{"number" => 2}) == "3"
    end

    test "custom filters on assign", %{opts: opts, date: date} do
      template = "{% assign variable = date_var | date_year %} {{- variable}}"

      assert render(template, %{"date_var" => date}, opts) == "2019"
    end
  end
end
