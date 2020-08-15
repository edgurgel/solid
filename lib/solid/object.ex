defmodule Solid.Object do
  @moduledoc """
  Liquid objects are arguments with filter(s) applied to them
  """
  alias Solid.Argument

  def render([], _context, _options), do: []

  def render(object, context, _options) when is_list(object) do
    argument = object[:argument]
    value = Argument.get(argument, context, filters: object[:filters])

    stringify!(value)
  end

  defp stringify!(value) when is_list(value) do
    value
    |> List.flatten()
    |> Enum.join()
  end

  defp stringify!(value), do: to_string(value)
end
