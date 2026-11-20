defmodule Solid.Tags.CollectionSlice do
  @moduledoc false
  # Shared `offset`/`limit` slicing for the `for` and `tablerow` tags.

  @doc """
  Returns the items of `enumerable` from index `from` up to (not including)
  index `to`. A `nil` `to` means "until the end".

  A string is never sliced: it is iterated once, as a whole.
  """
  @spec slice(Enumerable.t() | binary, integer, integer | nil) :: list
  def slice(string, _from, _to) when is_binary(string), do: [string]

  def slice(enumerable, from, nil), do: Enum.slice(enumerable, max(from, 0)..-1//1)

  def slice(enumerable, from, to) do
    start = max(from, 0)

    # Enum.slice/3 is O(count) on ranges, so a huge range is never materialized
    if to > start, do: Enum.slice(enumerable, start, to - start), else: []
  end
end
