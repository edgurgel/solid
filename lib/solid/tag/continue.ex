defmodule Solid.Tag.Continue do
  import NimbleParsec
  alias Solid.Parser.Tag

  @behaviour Solid.Tag

  @impl true
  def render([continue_exp: _], context, _options) do
    throw({:continue_exp, [], context})
  end

  @impl true
  def spec() do
    ignore(Tag.opening_tag())
    |> ignore(string("continue"))
    |> ignore(Tag.closing_tag())
    |> tag(:continue_exp)
  end
end
