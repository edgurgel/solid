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
  iex> Solid.Argument.get([field: ["value"]], %Solid.Context{vars: %{"value" => nil}})
  nil
  iex> Solid.Argument.get([field: ["value"]], %Solid.Context{vars: %{"value" => false}})
  false
  iex> Solid.Argument.get([field: ["value"]], %Solid.Context{vars: %{"value" => true}})
  true
  """
  @spec get([field: [String.t() | integer]] | [value: term], Context.t(), Keyword.t()) :: term
  def get(arg, context, opts \\ []) do
    scopes = Keyword.get(opts, :scopes, [:iteration_vars, :vars, :counter_vars])
    {filters, opts} = Keyword.pop(opts, :filters, [])

    value =
      case do_get(arg, context, scopes) do
        {:error, :not_found, key: key} ->
          if opts[:allow_undefined?] != true do
            Solid.ErrorContext.add_undefined_variable(key)
          end

          nil

        {:ok, result} ->
          result
      end

    apply_filters(value, filters, context, opts)
  end

  defp do_get([value: val], _hash, _scopes), do: {:ok, val}

  defp do_get([field: keys], context, scopes), do: Context.get_in(context, keys, scopes)

  defp apply_filters(input, nil, _context, _opts), do: input
  defp apply_filters(input, [], _context, _opts), do: input

  defp apply_filters(
         input,
         [{:filter, [filter, {:arguments, [{:named_arguments, args}]}]} | filters],
         context,
         opts
       ) do
    values = parse_named_arguments(args, context, opts)

    filter
    |> Filter.apply([input | values], opts)
    |> apply_filters(filters, context, opts)
  end

  defp apply_filters(input, [{:filter, [filter, {:arguments, args}]} | filters], context, opts) do
    values = for arg <- args, do: get([arg], context)

    filter
    |> Filter.apply([input | values], opts)
    |> apply_filters(filters, context, opts)
  end

  @spec parse_named_arguments(list, Context.t()) :: list
  def parse_named_arguments(ast, context, opts \\ []) do
    ast
    |> Enum.chunk_every(2)
    |> Map.new(fn [key, value_or_field] -> {key, get([value_or_field], context, opts)} end)
    |> List.wrap()
  end
end
