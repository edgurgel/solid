defmodule Solid.Tag.Break do
  import NimbleParsec
  alias Solid.Parser.BaseTag

  @behaviour Solid.Tag

  @impl true
  def spec(_parser) do
    ignore(BaseTag.opening_tag())
    |> ignore(string("break"))
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render(_tag, context, _options) do
    throw({:break_exp, [], context})
  end
end
