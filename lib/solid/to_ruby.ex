defmodule Solid.ToRuby do
  @doc """
  Converts an Elixir map to a Ruby-like hash string.

  ## Examples

      iex> Solid.ToRuby.hash(%{"title" => "Title 1"})
      "{\\"title\\"=>\\"Title 1\\"}"

  """
  def hash(map) when is_map(map) do
    pairs =
      map
      |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
      |> Enum.map(fn {key, value} ->
        "#{format(key)}=>#{format(value)}"
      end)

    "{#{Enum.join(pairs, ", ")}}"
  end

  defp format(nil), do: "nil"
  defp format(value) when is_boolean(value), do: to_string(value)
  defp format(value) when is_map(value), do: hash(value)
  defp format(value) when is_binary(value), do: "\"#{value}\""
  defp format(value) when is_atom(value), do: ":#{to_string(value)}"
  defp format(value) when is_number(value), do: to_string(value)

  defp format(value) when is_list(value) do
    formatted_elements = Enum.map(value, &format/1)
    "[#{Enum.join(formatted_elements, ", ")}]"
  end

  defp format(value), do: "\"#{to_string(value)}\""
end
