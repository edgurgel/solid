defmodule Solid.Object do
  @moduledoc """
  Liquid objects are arguments with filter(s) applied to them
  """
  alias Solid.{Argument, Filter}

  def render([], _context), do: []

  def render(object, context) when is_list(object) do
    argument = object[:argument]
    value = Argument.get(argument, context)

    filters = object[:filters]

    value
    |> apply_filters(filters, context)
    |> stringify!()
  end

  defp stringify!(value) when is_list(value) do
    value
    |> List.flatten()
    |> Enum.join()
  end

  defp stringify!(value) do
    to_string(value)
  end

  defp apply_filters(input, nil, _), do: input
  defp apply_filters(input, [], _), do: input

  defp apply_filters(input, [{:filter, [filter, {:arguments, args}]} | filters], context) do
    values = for arg <- args, do: Argument.get([arg], context)
    Filter.apply(filter, [input | values]) |> apply_filters(filters, context)
  end
end
