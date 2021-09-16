defmodule Solid.Tag.Raw do
  import NimbleParsec
  alias Solid.Parser.Tag

  @behaviour Solid.Tag

  @impl true
  def render([raw_exp: raw], context, _options) do
    {[text: raw], context}
  end

  @impl true
  def spec() do
    end_raw_tag =
      Tag.opening_tag()
      |> ignore(string("endraw"))
      |> ignore(Tag.closing_tag())

    ignore(Tag.opening_tag())
    |> ignore(string("raw"))
    |> ignore(Tag.closing_tag())
    |> repeat(lookahead_not(ignore(end_raw_tag)) |> utf8_char([]))
    |> ignore(end_raw_tag)
    |> tag(:raw_exp)
  end
end
