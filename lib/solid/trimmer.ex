defmodule Solid.Trimmer do
  def trim_current(string, false), do: string

  def trim_current([string], true) when is_binary(string) do
    [String.trim_leading(string)]
  end

  def trim_current([charlist], true) when is_list(charlist) do
    [to_string(charlist) |> String.trim_leading()]
  end

  def trim_current(charlist, true) when is_list(charlist) do
    to_string(charlist) |> String.trim_leading()
  end

  def trim_current(string, true) do
    String.trim_leading(string)
  end

  def trim_previous(iolist, false), do: iolist
  def trim_previous([], _), do: []

  def trim_previous([[string] | tail], true) do
    [[String.trim_trailing(string)] | tail]
  end
end
