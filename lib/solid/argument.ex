defmodule Solid.Argument do
  @moduledoc """
  An Argument can be a field that will be inside the context or
  a value (String, Integer, etc)
  """

  alias Solid.Context

  @doc """
  iex> Solid.Argument.get([field: [keys: ["key"], accesses: []]], %Solid.Context{vars: %{"key" => 123}})
  123
  iex> Solid.Argument.get([field: [keys: ["key1", "key2"], accesses: []]], %Solid.Context{vars: %{"key1" => %{"key2" => 123}}})
  123
  iex> Solid.Argument.get([value: "value"], %Solid.Context{})
  "value"
  iex> Solid.Argument.get([field: [keys: ["key"], accesses: [access: 1, access: 1]]], %Solid.Context{vars: %{"key" => [1, [1,2,3], 3]}})
  2
  iex> Solid.Argument.get([field: [keys: ["key"], accesses: [access: 1]]], %Solid.Context{vars: %{"key" => "a string"}})
  nil
  """
  @spec get(
          [field: [keys: [String.t()], accesses: [{:access, non_neg_integer}]]]
          | [value: term],
          Context.t(),
          [atom]
        ) :: term
  def get(field, context, scopes \\ [:vars, :counter_vars])
  def get([value: val], _hash, _scopes), do: val

  def get([field: [keys: keys, accesses: accesses]], context, scopes) do
    value = Context.get_in(context, keys, scopes)

    Enum.reduce(accesses, value, fn
      {:access, index}, acc when is_list(acc) ->
        Enum.at(acc, index)

      _, _ ->
        nil
    end)
  end
end
