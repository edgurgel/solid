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
    Regex.replace(~r/%\{(\w+)\}/, message, fn _, key -> Map.get(bindings, key) || "" end)
  end

  def asset_url(input, opts) do
    url = Keyword.get(opts, :"#{input}", "")
    url <> input
  end
end
