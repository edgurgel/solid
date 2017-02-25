defmodule Solid.Argument do
  @moduledoc """
  An Argument can be a field that will be inside the context or
  a value (String, Integer, etc)
  """

  alias Solid.Context

  @doc """
  iex> Solid.Argument.get({:field, "key"}, %Solid.Context{vars: %{"key" => 123}})
  123
  iex> Solid.Argument.get({:field, "key1.key2"}, %Solid.Context{vars: %{"key1" => %{"key2" => 123}}})
  123
  iex> Solid.Argument.get({:value, "value"}, %Solid.Context{})
  "value"
  """
  @spec get({:field, String.t} | {:value, term}, Context.t) :: term
  def get({:field, key}, %Context{vars: vars}) do
    key = key |> String.split(".")
    get_in(vars, key)
  end
  def get({:value, val}, _hash), do: val
end
