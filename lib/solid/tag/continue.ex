defmodule Solid.Tag.Continue do
  import NimbleParsec
  alias Solid.Parser.BaseTag

  @behaviour Solid.Tag

  @impl true
  def spec() do
    ignore(BaseTag.opening_tag())
    |> ignore(string("continue"))
    |> ignore(BaseTag.closing_tag())
    |> tag(:continue_exp)
  end

  @impl true
  def render([continue_exp: _], context, _options) do
    throw({:continue_exp, [], context})
  end
end
