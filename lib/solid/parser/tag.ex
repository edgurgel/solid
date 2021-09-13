defmodule Solid.Parser.Tag do
  import NimbleParsec

  defp space(), do: Solid.Parser.Literal.whitespace(min: 0)

  def opening_tag() do
    string("{%")
    |> concat(optional(string("-")))
    |> concat(space())
  end

  def closing_tag() do
    closing_wc_tag = string("-%}")

    closing_wc_tag_and_whitespace =
      closing_wc_tag
      |> concat(space())
      |> ignore()

    space()
    |> concat(choice([closing_wc_tag_and_whitespace, string("%}")]))
  end
end
