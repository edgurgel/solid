defmodule Solid.Parser.BaseTag do
  import NimbleParsec

  space = Solid.Parser.Literal.whitespace(min: 0)

  @opening_tag string("{%")
               |> concat(optional(string("-")))
               |> concat(space)

  def opening_tag(), do: @opening_tag

  defcombinator(:opening_tag, @opening_tag)

  closing_wc_tag_and_whitespace =
    string("-%}")
    |> concat(space)
    |> ignore()

  @closing_tag space
               |> concat(choice([closing_wc_tag_and_whitespace, string("%}")]))

  def closing_tag(), do: @closing_tag

  defcombinator(:closing_tag, @closing_tag)

  def else_tag(parser) do
    ignore(parsec({__MODULE__, :opening_tag}))
    |> ignore(string("else"))
    |> ignore(parsec({__MODULE__, :closing_tag}))
    |> tag(parsec({parser, :liquid_entry}), :result)
  end
end
