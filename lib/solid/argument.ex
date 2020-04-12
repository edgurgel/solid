defmodule Solid.Argument do
  @moduledoc """
  An Argument can be a field that will be inside the context or
  a value (String, Integer, etc)
  """

  alias Solid.Context

  @doc """
  iex> Solid.Argument.get([field: ["key"]], %Solid.Context{vars: %{"key" => 123}})
  123
  iex> Solid.Argument.get([field: ["key1", "key2"]], %Solid.Context{vars: %{"key1" => %{"key2" => 123}}})
  123
  iex> Solid.Argument.get([value: "value"], %Solid.Context{})
  "value"
  iex> Solid.Argument.get([field: ["key", 1, 1]], %Solid.Context{vars: %{"key" => [1, [1,2,3], 3]}})
  2
  iex> Solid.Argument.get([field: ["key", 1]], %Solid.Context{vars: %{"key" => "a string"}})
  nil
  iex> Solid.Argument.get([field: ["key", 1, "foo"]], %Solid.Context{vars: %{"key" => [%{"foo" => "bar1"}, %{"foo" => "bar2"}]}})
  "bar2"
  """
  @spec get([field: [String.t()]] | [value: term], Context.t(), [atom]) :: term
  def get(field, context, scopes \\ [:iteration_vars, :vars, :counter_vars])
  def get([value: val], _hash, _scopes), do: val

  def get([field: keys], context, scopes) do
    Context.get_in(context, keys, scopes)
  end
end
