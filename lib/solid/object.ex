defmodule Solid.Object do
  @moduledoc """
  Liquid objects are arguments with filter(s) applied to them
  """
  alias Solid.{Argument, Context}

  @spec render(Keyword.t(), Context.t(), Keyword.t()) :: String.t()
  def render([], _context, _options), do: []

  def render(object, context, options) when is_list(object) do
    argument = object[:argument]
    value = Argument.get(argument, context, [filters: object[:filters]] ++ options)

    stringify!(value)
    |> warn_on_empty(argument: argument, filters: object[:filters])
  end

  defp stringify!(value) when is_list(value) do
    value
    |> List.flatten()
    |> Enum.join()
  end

  defp stringify!(value) when is_map(value) and not is_struct(value) do
    "#{inspect(value)}"
  end

  defp stringify!(value), do: to_string(value)

  defp warn_on_empty(value = "", argument: [field: key], filters: filters) do
    Solid.ErrorContext.add_empty_warning(key, filters)
    value
  end

  defp warn_on_empty(value, _opts), do: value
end
