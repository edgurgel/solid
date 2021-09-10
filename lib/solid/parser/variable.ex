defmodule Solid.Parser.Variable do
  import NimbleParsec
  alias Solid.Parser.Literal

  defp identifier(), do: ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ??], min: 1)

  def bracket_access do
    ignore(string("["))
    |> choice([Literal.int(), Literal.single_quoted_string(), Literal.double_quoted_string()])
    |> ignore(string("]"))
  end

  def dot_access do
    ignore(string("."))
    |> concat(identifier())
  end

  def field do
    identifier()
    |> repeat(choice([dot_access(), bracket_access()]))
    |> tag(:field)
  end
end
