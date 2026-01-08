defmodule Solid.Argument do
  alias Solid.{
    Context,
    Filter,
    Lexer,
    Literal,
    StandardFilter,
    UndefinedVariableError,
    Variable
  }

  alias Solid.Parser.Loc
  import Solid.NumberHelper, only: [to_integer: 1]

  @type t :: Variable.t() | Literal.t() | Solid.Range.t()

  @spec parse(Lexer.tokens()) ::
          {:ok, t, Lexer.tokens()} | {:error, binary, Lexer.loc()}
  def parse(tokens) do
    case Literal.parse(tokens) do
      {:ok, literal, rest} -> {:ok, literal, rest}
      {:error, _, _} -> parse_range(tokens)
    end
  end

  defp parse_range(tokens) do
    case Solid.Range.parse(tokens) do
      {:ok, range, rest} -> {:ok, range, rest}
      {:error, _, _} -> parse_variable(tokens)
    end
  end

  defp parse_variable(tokens) do
    case Variable.parse(tokens) do
      {:ok, var, rest} ->
        {:ok, var, rest}

      {:error, "Variable expected", meta} ->
        {:error, "Argument expected", meta}

      {:error, reason, meta} ->
        {:error, reason, meta}
    end
  end

  @spec parse_with_filters(Lexer.tokens()) ::
          {:ok, t, [Filter.t()], Lexer.tokens()} | {:error, binary, Lexer.loc()}
  def parse_with_filters(tokens) do
    with {:ok, argument, rest} <- parse(tokens),
         {:ok, filters, rest} <- filters(rest) do
      {:ok, argument, filters, rest}
    end
  end

  defp filters(tokens, filters \\ []) do
    case tokens do
      [{:pipe, _}, {:identifier, meta, filter} | rest] ->
        case rest do
          [{:colon, colon_meta} | rest] ->
            case arguments(rest) do
              {:ok, [], positional_arguments, _} when map_size(positional_arguments) == 0 ->
                {:error, "Arguments expected", colon_meta}

              {:ok, positional_arguments, named_arguments, rest} ->
                filter =
                  %Filter{
                    loc: struct!(Loc, meta),
                    function: filter,
                    positional_arguments: positional_arguments,
                    named_arguments: named_arguments
                  }

                filters(rest, [filter | filters])

              error ->
                error
            end

          _ ->
            filter =
              %Filter{
                loc: struct!(Loc, meta),
                function: filter,
                positional_arguments: [],
                named_arguments: %{}
              }

            filters(rest, [filter | filters])
        end

      [{:pipe, meta} | _rest] ->
        {:error, "Filter expected", meta}

      _ ->
        {:ok, Enum.reverse(filters), tokens}
    end
  end

  defp arguments(tokens, positional_arguments \\ [], named_arguments \\ %{})

  defp arguments([{:end, _}] = tokens, positional_arguments, named_arguments),
    do: {:ok, Enum.reverse(positional_arguments), named_arguments, tokens}

  # Another filter coming up
  defp arguments([{:pipe, _} | _rest] = tokens, positional_arguments, named_arguments) do
    {:ok, Enum.reverse(positional_arguments), named_arguments, tokens}
  end

  defp arguments(tokens, positional_arguments, named_arguments) do
    case tokens do
      [{:identifier, _meta, variable_name}, {:colon, _} | rest] ->
        case parse(rest) do
          {:ok, argument, rest} ->
            named_arguments = Map.put(named_arguments, variable_name, argument)

            case rest do
              [{:comma, _} | rest] ->
                arguments(rest, positional_arguments, named_arguments)

              _ ->
                {:ok, Enum.reverse(positional_arguments), named_arguments, rest}
            end

          error ->
            error
        end

      _rest ->
        case parse(tokens) do
          {:ok, argument, rest} ->
            positional_arguments = [argument | positional_arguments]

            case rest do
              [{:comma, _} | rest] ->
                arguments(rest, positional_arguments, named_arguments)

              _ ->
                {:ok, Enum.reverse(positional_arguments), named_arguments, rest}
            end

          error ->
            error
        end
    end
  end

  @doc "Similar to get/4 but outputs a printable representation"
  @spec render(t, Context.t(), [Filter.t()], Keyword.t()) :: {:ok, binary, Context.t()}
  def render(arg, context, filters, opts \\ []) do
    {:ok, value, context} = get(arg, context, filters, opts)

    {:ok, stringify!(value), context}
  end

  defp stringify!(value) when is_list(value) do
    value
    |> List.flatten()
    |> Enum.join()
  end

  defp stringify!(value) when is_map(value) and not is_struct(value) do
    "#{inspect(value)}"
  end

  defp stringify!(%Literal.Empty{}), do: ""

  defp stringify!(range) when is_struct(range, Range) do
    "#{range.first}..#{range.last}"
  end

  defp stringify!(two_tuple) when is_tuple(two_tuple) and tuple_size(two_tuple) == 2 do
    "#{elem(two_tuple, 0)}#{elem(two_tuple, 1)}"
  end

  defp stringify!(value), do: to_string(value)

  @spec get(t, Context.t(), [Filter.t()], Keyword.t()) :: {:ok, term, Context.t()}
  def get(arg, context, filters, opts \\ []) do
    scopes = Keyword.get(opts, :scopes, [:iteration_vars, :vars, :counter_vars])
    strict_variables = Keyword.get(opts, :strict_variables, false)

    case do_get(arg, context, scopes, opts) do
      {:ok, value, context} ->
        {value, context} = apply_filters(value, filters, context, opts)
        {:ok, value, context}

      {:error, {:not_found, key}, context} ->
        context =
          if strict_variables do
            Context.put_errors(context, %UndefinedVariableError{
              variable: key,
              original_name: arg.original_name,
              loc: arg.loc
            })
          else
            context
          end

        {value, context} = apply_filters(nil, filters, context, opts)
        {:ok, value, context}
    end
  end

  defp do_get(%Literal{value: value}, context, _scopes, _options), do: {:ok, value, context}

  defp do_get(%Variable{} = variable, context, scopes, options),
    do: Context.get_in(context, variable, scopes, options)

  defp do_get(%Solid.Range{} = range, context, _scopes, options) do
    {:ok, start, context} = get(range.start, context, [], options)
    {:ok, finish, context} = get(range.finish, context, [], options)

    start =
      case to_integer(start) do
        {:ok, integer} -> integer
        _ -> 0
      end

    finish =
      case to_integer(finish) do
        {:ok, integer} -> integer
        _ -> 0
      end

    {:ok, start..finish//1, context}
  end

  defp apply_filters(input, nil, context, _opts), do: {input, context}
  defp apply_filters(input, [], context, _opts), do: {input, context}

  defp apply_filters(input, [filter | filters], context, opts) do
    %Filter{
      loc: loc,
      function: filter,
      positional_arguments: args,
      named_arguments: named_args
    } = filter

    {values, context} =
      Enum.reduce(args, {[], context}, fn arg, {values, context} ->
        {:ok, value, context} = get(arg, context, [], opts)

        {[value | values], context}
      end)

    {named_values, context} =
      Enum.reduce(named_args, {%{}, context}, fn {key, value}, {named_values, context} ->
        {:ok, named_value, context} = get(value, context, [], opts)

        {Map.put(named_values, key, named_value), context}
      end)

    filter_args =
      if named_values != %{} do
        [input | Enum.reverse(values)] ++ [named_values]
      else
        [input | Enum.reverse(values)]
      end

    filter
    |> StandardFilter.apply(filter_args, loc, opts)
    |> case do
      {:error, exception, value} ->
        {value, Context.put_errors(context, exception)}

      {:error, exception} ->
        {Exception.message(exception), Context.put_errors(context, exception)}

      {:ok, value} ->
        {value, context}
        apply_filters(value, filters, context, opts)
    end
  end
end
