defmodule Solid.Tag.Raw do
  import NimbleParsec
  alias Solid.Parser.BaseTag

  @behaviour Solid.Tag

  @impl true
  def spec(_parser) do
    end_raw_tag =
      BaseTag.opening_tag()
      |> ignore(string("endraw"))
      |> ignore(BaseTag.closing_tag())

    ignore(BaseTag.opening_tag())
    |> ignore(string("raw"))
    |> ignore(BaseTag.closing_tag())
    |> repeat(lookahead_not(ignore(end_raw_tag)) |> utf8_char([]))
    |> ignore(end_raw_tag)
  end

  @impl true
  def render(raw, context, _options) do
    {[text: raw], context}
  end
end
