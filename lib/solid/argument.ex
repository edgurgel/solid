defmodule Solid.Argument do
  @moduledoc """
  An Argument can be a field that will be inside the context or
  a value (String, Integer, etc)
  """

  alias Solid.{Context, Filter, UndefinedVariableError}

  @spec get([field: [String.t() | integer]] | [value: term], Context.t(), Keyword.t()) ::
          {:ok, term, Context.t()}
  def get(arg, context, opts \\ []) do
    scopes = Keyword.get(opts, :scopes, [:iteration_vars, :vars, :counter_vars])
    {filters, opts} = Keyword.pop(opts, :filters, [])
    strict_variables = Keyword.get(opts, :strict_variables, false)

    case do_get(arg, context, scopes) do
      {:ok, value} ->
        {value, context} = apply_filters(value, filters, context, opts)
        {:ok, value, context}

      {:error, {:not_found, key}} ->
        context =
          if strict_variables do
            Context.put_errors(context, %UndefinedVariableError{variable: key})
          else
            context
          end

        {value, context} = apply_filters(nil, filters, context, opts)
        {:ok, value, context}
    end
  end

  defp do_get([value: val], _hash, _scopes), do: {:ok, val}

  defp do_get([field: keys], context, scopes), do: Context.get_in(context, keys, scopes)

  defp apply_filters(input, nil, context, _opts), do: {input, context}
  defp apply_filters(input, [], context, _opts), do: {input, context}

  defp apply_filters(
         input,
         [{:filter, [filter, {:arguments, [{:named_arguments, args}]}]} | filters],
         context,
         opts
       ) do
    {:ok, values, context} = parse_named_arguments(args, context, opts)

    {result, context} =
      filter
      |> Filter.apply([input | values], opts)
      |> case do
        {:error, exception, value} ->
          {value, Context.put_errors(context, exception)}

        {:ok, value} ->
          {value, context}
      end

    apply_filters(result, filters, context, opts)
  end

  defp apply_filters(input, [{:filter, [filter, {:arguments, args}]} | filters], context, opts) do
    {values, context} =
      Enum.reduce(args, {[], context}, fn arg, {values, context} ->
        {:ok, value, context} = get([arg], context, opts)
        {[value | values], context}
      end)

    {result, context} =
      filter
      |> Filter.apply([input | Enum.reverse(values)], opts)
      |> case do
        {:error, exception, value} ->
          {value, Context.put_errors(context, exception)}

        {:ok, value} ->
          {value, context}
      end

    apply_filters(result, filters, context, opts)
  end

  @spec parse_named_arguments(list, Context.t(), Keyword.t()) :: {:ok, list, Context.t()}
  def parse_named_arguments(ast, context, opts \\ []) do
    {named_arguments, context} =
      ast
      |> Enum.chunk_every(2)
      |> Enum.reduce({%{}, context}, fn [key, value_or_field], {named_arguments, context} ->
        {:ok, value, context} = get([value_or_field], context, opts)
        {Map.put(named_arguments, key, value), context}
      end)

    {:ok, List.wrap(named_arguments), context}
  end
end
