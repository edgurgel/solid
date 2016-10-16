defmodule Solid.Argument do
  @moduledoc """
  An Argument can be a field that will be inside the hash or
  a value (String, Integer, etc)
  """

  @doc """
  iex> Solid.Argument.get({:field, "key"}, %{"key" => 123})
  123
  iex> Solid.Argument.get({:field, "key1.key2"}, %{"key1" => %{"key2" => 123}})
  123
  iex> Solid.Argument.get({:value, "value"}, %{})
  "value"
  """
  @spec get({:field, String.t} | {:value, term}, Map.t) :: term
  def get({:field, key}, hash) do
    key = key |> String.split(".")
    get_in(hash, key)
  end
  def get({:value, val}, _hash), do: val
end
