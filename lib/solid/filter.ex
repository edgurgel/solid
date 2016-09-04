defmodule Solid.Filter do
  @moduledoc """
  Standard filters
  """

  def default(nil, value), do: value
  def default(input, _), do: input

  def upcase(input), do: input |> to_string |> String.upcase

  def downcase(input), do: input |> to_string |> String.downcase

  def replace(input, string, replacement \\ "") do
    input |> to_string |> String.replace(string, replacement)
  end
end
