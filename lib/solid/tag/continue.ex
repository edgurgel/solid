defmodule Solid.Tag.Continue do
  import NimbleParsec
  alias Solid.Parser.BaseTag

  @behaviour Solid.Tag

  @impl true
  def spec(_parser) do
    ignore(BaseTag.opening_tag())
    |> ignore(string("continue"))
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render(_tag, context, _options) do
    throw({:continue_exp, [], context})
  end
end
