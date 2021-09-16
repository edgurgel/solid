defmodule Solid.Tag.Break do
  import NimbleParsec
  alias Solid.Parser.BaseTag

  @behaviour Solid.Tag

  @impl true
  def spec() do
    ignore(BaseTag.opening_tag())
    |> ignore(string("break"))
    |> ignore(BaseTag.closing_tag())
    |> tag(:break_exp)
  end

  @impl true
  def render([break_exp: _], context, _options) do
    throw({:break_exp, [], context})
  end
end
