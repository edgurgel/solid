defmodule Solid.Context do
  defstruct vars: %{}, counter_vars: %{}
  @type t :: %__MODULE__{vars: Map.t, counter_vars: Map.t}
  @type scope :: :counter_vars | :vars

  @doc """
  Get data from context respecting the scope order provided.

  Possible scope values: :counter_vars or :vars
  """
  @spec get_in(t(), [term()], [scope]) :: term
  def get_in(context, key, scopes) do
    Enum.reduce(scopes, nil, fn scope, value -> get_from_scope(context, scope, key, value) end)
  end

  defp get_from_scope(context, :vars, key, nil) do
    Kernel.get_in(context.vars, key)
  end

  defp get_from_scope(context, :counter_vars, key, nil) do
    Kernel.get_in(context.counter_vars, key)
  end

  defp get_from_scope(_context, _scope, _key, value), do: value
end
