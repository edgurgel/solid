defmodule Solid.Context do
  alias Solid.{AccessLiteral, AccessVariable, Argument, Literal, Variable}

  defstruct vars: %{},
            counter_vars: %{},
            iteration_vars: %{},
            cycle_state: %{},
            registers: %{},
            errors: [],
            matcher_module: Solid.Matcher

  @type t :: %__MODULE__{
          vars: map,
          counter_vars: map,
          iteration_vars: %{optional(String.t()) => term},
          cycle_state: map,
          registers: map,
          errors: Solid.errors(),
          matcher_module: module
        }
  @type scope :: :counter_vars | :vars | :iteration_vars

  def put_errors(context, errors) when is_list(errors) do
    %{context | errors: errors ++ context.errors}
  end

  def put_errors(context, error) do
    %{context | errors: [error | context.errors]}
  end

  @doc """
  Get data from context respecting the provided scope order.

  Possible scope values: :counter_vars, :vars or :iteration_vars
  """
  @spec get_in(t, Variable.t(), [scope], keyword) ::
          {:ok, term, t} | {:error, {:not_found, [term()]}, t}
  def get_in(context, variable, scopes, opts \\ []) do
    {keys, context} =
      Enum.reduce(variable.accesses, {[], context}, fn access, {keys, context} ->
        case access do
          %AccessLiteral{value: value} ->
            {[value | keys], context}

          %AccessVariable{variable: access_variable} ->
            {:ok, v, context} = Argument.get(access_variable, context, [], opts)

            {[v | keys], context}
        end
      end)

    # This exists here for the case when there is no initial identifier like:
    # {{ [foo] }}
    # In this case we start directly on the context vars
    keys =
      if variable.identifier do
        [variable.identifier | Enum.reverse(keys)]
      else
        Enum.reverse(keys)
      end

    result = get_from_scope(context, scopes, keys)

    Tuple.insert_at(result, 2, context)
  end

  @spec get_counter(t, [String.t()]) :: term | nil
  def get_counter(context, name) do
    case get_from_scope(context, :counter_vars, name) do
      {:ok, value} -> value
      {:error, :not_found} -> nil
    end
  end

  defp cycle_slug(%Literal{value: value}), do: "l:#{value}"

  defp cycle_slug(%Variable{} = variable) do
    # Using inspect here to include Parser.Loc and ensure variables are always different because that's how liquid treats it
    "v:#{inspect(variable)}-" <> cycle_slug(variable.accesses)
  end

  defp cycle_slug(%AccessLiteral{value: value}), do: "al:#{value}"
  defp cycle_slug(%AccessVariable{variable: variable}), do: "av:#{variable}"

  defp cycle_slug(list) when is_list(list) do
    list
    |> Enum.map(&cycle_slug/1)
    |> Enum.join(",")
  end

  @doc """
  Find the current value that `cycle` must return
  """
  @spec run_cycle(t(), name :: Argument.t() | nil, values :: [Argument.t()]) ::
          {t(), Argument.t() | nil}
  def run_cycle(%__MODULE__{cycle_state: cycle_state} = context, name, values) do
    {name, context} =
      if name do
        # Liquid gem seems to evaluate when it's properly named
        {:ok, value, context} = Argument.get(name, context, [])
        {value, context}
      else
        {cycle_slug(name || values), context}
      end

    case cycle_state[name] do
      {current_index, cycle_map} ->
        limit = map_size(cycle_map)
        next_index = if current_index + 1 < limit, do: current_index + 1, else: 0

        cycle_map = cycle_to_map(values)
        cycle_state = %{context.cycle_state | name => {next_index, cycle_map}}

        {%{context | cycle_state: cycle_state}, cycle_map[next_index]}

      nil ->
        cycle_map = cycle_to_map(values)
        current_index = 0

        {%{context | cycle_state: Map.put_new(cycle_state, name, {current_index, cycle_map})},
         cycle_map[current_index]}
    end
  end

  defp cycle_to_map(cycle) do
    cycle
    |> Enum.with_index()
    |> Enum.into(%{}, fn {value, index} -> {index, value} end)
  end

  defp get_from_scope(context, scopes, variable) when is_list(scopes) do
    scopes
    |> Enum.reverse()
    |> Enum.map(&get_from_scope(context, &1, variable))
    |> Enum.reduce({:error, {:not_found, variable}}, fn
      {:ok, nil}, acc = {:ok, _} -> acc
      value = {:ok, _}, _acc -> value
      _value, acc -> acc
    end)
  end

  defp get_from_scope(context, :vars, variable) do
    context.matcher_module.match(context.vars, variable)
  end

  defp get_from_scope(context, :counter_vars, variable) do
    context.matcher_module.match(context.counter_vars, variable)
  end

  defp get_from_scope(context, :iteration_vars, variable) do
    context.matcher_module.match(context.iteration_vars, variable)
  end
end
