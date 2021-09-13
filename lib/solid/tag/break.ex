defmodule Solid.Tag.Break do
  import NimbleParsec
  alias Solid.Parser.Tag

  @behaviour Solid.Tag

  @impl true
  def render([break_exp: _], context, _options) do
    throw({:break_exp, [], context})
  end

  @impl true
  def spec() do
    ignore(Tag.opening_tag())
    |> ignore(string("break"))
    |> ignore(Tag.closing_tag())
    |> tag(:break_exp)
  end
end
