defmodule Solid.Argument do
  @moduledoc """
  An Argument can be a field that will be inside the context or
  a value (String, Integer, etc)
  """

  alias Solid.{Context, Filter}

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
  @spec get([field: [String.t() | integer]] | [value: term], Context.t(), Keyword.t()) :: term
  def get(arg, context, opts \\ []) do
    scopes = Keyword.get(opts, :scopes, [:iteration_vars, :vars, :counter_vars])
    filters = Keyword.get(opts, :filters, [])

    arg
    |> do_get(context, scopes)
    |> apply_filters(filters, context)
  end

  defp do_get([value: val], _hash, _scopes), do: val

  defp do_get([field: keys], context, scopes), do: Context.get_in(context, keys, scopes)

  defp apply_filters(input, nil, _), do: input
  defp apply_filters(input, [], _), do: input

  defp apply_filters(
         input,
         [{:filter, [filter, {:arguments, [{:named_arguments, args}]}]} | filters],
         context
       ) do
    values = parse_named_arguments(args, context)

    filter
    |> Filter.apply([input | values])
    |> apply_filters(filters, context)
  end

  defp apply_filters(input, [{:filter, [filter, {:arguments, args}]} | filters], context) do
    values = for arg <- args, do: get([arg], context)

    filter
    |> Filter.apply([input | values])
    |> apply_filters(filters, context)
  end

  defp parse_named_arguments(ast, context) do
    ast
    |> Enum.chunk_every(2)
    |> Map.new(fn [key, value_or_field] -> {key, get([value_or_field], context)} end)
    |> List.wrap()
  end
end
