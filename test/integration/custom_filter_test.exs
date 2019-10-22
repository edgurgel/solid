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
      assert render(~s<{{ date_var | date_format: "m/d/yyyy" }}>, %{"date_var" => date}) == "10/31/2019"
    end

    test "date format d.m.yyyy", %{date: date} do
      assert render(~s<{{ date_var | date_format: "d.m.yyyy" }}>, %{"date_var" => date}) == "31.10.2019"
    end

    test "date format with malformed format", %{date: date} do
      assert render(~s<{{ date_var | date_format: "x/y/z" }}>, %{"date_var" => date} == "2019-10-31")
    end
  end
end
