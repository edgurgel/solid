defmodule Solid.Tag.Comment do
  import NimbleParsec
  alias Solid.Parser.BaseTag

  @behaviour Solid.Tag

  @impl true
  def spec() do
    end_comment_tag =
      ignore(BaseTag.opening_tag())
      |> ignore(string("endcomment"))
      |> ignore(BaseTag.closing_tag())

    ignore(BaseTag.opening_tag())
    |> ignore(string("comment"))
    |> ignore(BaseTag.closing_tag())
    |> ignore(repeat(lookahead_not(ignore(end_comment_tag)) |> utf8_char([])))
    |> ignore(end_comment_tag)
  end

  @impl true
  def render(_tag, context, _options) do
    {nil, context}
  end
end
