defmodule Solid.Tag.Comment do
  import NimbleParsec
  alias Solid.Parser.Tag

  @behaviour Solid.Tag

  @impl true
  def render(_tag, _context, _options) do
  end

  @impl true
  def spec() do
    end_comment_tag =
      ignore(Tag.opening_tag())
      |> ignore(string("endcomment"))
      |> ignore(Tag.closing_tag())

    ignore(Tag.opening_tag())
    |> ignore(string("comment"))
    |> ignore(Tag.closing_tag())
    |> ignore(repeat(lookahead_not(ignore(end_comment_tag)) |> utf8_char([])))
    |> ignore(end_comment_tag)
  end
end
