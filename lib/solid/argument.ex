defmodule Solid.Argument do
  def get({:field, key}, hash) do
    key = key |> String.split(".")
    get_in(hash, key)
  end
  def get({:value, val}, _hash), do: val
end
