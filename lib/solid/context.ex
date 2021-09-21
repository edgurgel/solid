defmodule Solid.Context do
  defstruct vars: %{}, counter_vars: %{}, iteration_vars: %{}, cycle_state: %{}

  @type t :: %__MODULE__{
          vars: map,
          counter_vars: map,
          iteration_vars: %{optional(String.t()) => term},
          cycle_state: map
        }
  @type scope :: :counter_vars | :vars | :iteration_vars

  @doc """
  Get data from context respecting the scope order provided.

  Possible scope values: :counter_vars, :vars or :iteration_vars
  """
  @spec get_in(t(), [term()], [scope]) :: term
  def get_in(context, key, scopes) do
    {:ok, result} =
      scopes
      |> Enum.map(&get_from_scope(context, &1, key))
      |> Enum.find({:ok, nil}, fn
        {:ok, _} -> true
        _ -> false
      end)

    result
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
    do_get_in(context.vars, key)
  end

  defp get_from_scope(context, :counter_vars, key) do
    do_get_in(context.counter_vars, key)
  end

  defp get_from_scope(context, :iteration_vars, key) do
    do_get_in(context.iteration_vars, key)
  end

  defp do_get_in(nil, _), do: {:error, :not_found}
  defp do_get_in(data, []), do: {:ok, data}

  defp do_get_in(data, ["size"]) when is_list(data) do
    {:ok, Enum.count(data)}
  end

  defp do_get_in(data, ["size"]) when is_map(data) do
    {:ok, Map.get(data, "size", Enum.count(data))}
  end

  defp do_get_in(data, ["size"]) when is_binary(data) do
    {:ok, String.length(data)}
  end

  defp do_get_in(data, [key | keys]) when is_map(data) do
    do_get_in(data[key], keys)
  end

  defp do_get_in(data, [key | keys]) when is_integer(key) and is_list(data) do
    do_get_in(Enum.at(data, key), keys)
  end

  defp do_get_in(_, _), do: {:error, :not_found}
end
