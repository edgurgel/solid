defmodule Solid.UndefinedVariableError do
  defexception [:variable]

  @impl true
  def message(exception), do: "Undefined variable #{exception.variable}"
end

defmodule Solid.UndefinedFilterError do
  defexception [:filter]

  @impl true
  def message(exception), do: "Undefined filter #{exception.filter}"
end

defmodule Solid.Context do
  defstruct vars: %{}, counter_vars: %{}, iteration_vars: %{}, cycle_state: %{}, errors: []

  @type t :: %__MODULE__{
          vars: map,
          counter_vars: map,
          iteration_vars: %{optional(String.t()) => term},
          cycle_state: map,
          errors: list(Solid.UndefinedVariableError)
        }
  @type scope :: :counter_vars | :vars | :iteration_vars

  def put_errors(context, errors) when is_list(errors) do
    %{context | errors: errors ++ context.errors}
  end

  def put_errors(context, error) do
    %{context | errors: [error | context.errors]}
  end

  @doc """
  Get data from context respecting the scope order provided.

  Possible scope values: :counter_vars, :vars or :iteration_vars
  """
  @spec get_in(t(), [term()], [scope]) :: {:ok, term} | {:error, {:not_found, [term()]}}
  def get_in(context, key, scopes) do
    scopes
    |> Enum.reverse()
    |> Enum.map(&get_from_scope(context, &1, key))
    |> Enum.reduce({:error, {:not_found, key}}, fn
      {:ok, nil}, acc = {:ok, _} -> acc
      value = {:ok, _}, _acc -> value
      _value, acc -> acc
    end)
  end

  @doc """
  Find the current value that `cycle` must return
  """
  @spec run_cycle(t(), [values: [String.t()]] | [name: String.t(), values: [String.t()]]) ::
          {t(), String.t()}
  def run_cycle(%__MODULE__{cycle_state: cycle_state} = context, cycle) do
    name = Keyword.get(cycle, :name, cycle[:values])

    case cycle_state[name] do
      {current_index, cycle_map} ->
        limit = map_size(cycle_map)
        next_index = if current_index + 1 < limit, do: current_index + 1, else: 0

        {%{context | cycle_state: %{context.cycle_state | name => {next_index, cycle_map}}},
         cycle_map[next_index]}

      nil ->
        values = Keyword.fetch!(cycle, :values)
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

  defp get_from_scope(context, :vars, key) do
    Solid.Matcher.match(context.vars, key)
  end

  defp get_from_scope(context, :counter_vars, key) do
    Solid.Matcher.match(context.counter_vars, key)
  end

  defp get_from_scope(context, :iteration_vars, key) do
    Solid.Matcher.match(context.iteration_vars, key)
  end
end
