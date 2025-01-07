defmodule Solid.Parser.Variable do
  import NimbleParsec
  alias Solid.Parser.Literal

  @dialyzer :no_opaque

  defp identifier(), do: ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ??], min: 1)

  def bracket_access do
    ignore(string("["))
    |> choice([
      Literal.int(),
      Literal.single_quoted_string(),
      Literal.double_quoted_string(),
      unwrap_and_tag(identifier(), :reference)
    ])
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
    |> map({__MODULE__, :reserved_words, []})
  end

  @reserved_words ~w(true false nil empty)

  def reserved_words(field) do
    case field do
      {:field, [word]} when word in @reserved_words -> {:value, String.to_atom(word)}
      _ -> field
    end
  end
end
