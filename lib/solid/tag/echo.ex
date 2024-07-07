defmodule Solid.Tag.Echo do
  import NimbleParsec
  alias Solid.Parser.{BaseTag, Literal, Argument}

  @behaviour Solid.Tag

  @impl true
  def spec(_parser) do
    space = Literal.whitespace(min: 0)

    ignore(BaseTag.opening_tag())
    |> ignore(string("echo"))
    |> ignore(space)
    |> tag(Argument.argument(), :argument)
    |> optional(tag(repeat(Argument.filter()), :filters))
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render([argument: argument, filters: filters], context, options) do
    {:ok, value, context} =
      Solid.Argument.get(argument, context, [{:filters, filters} | options])

    {[text: value], context}
  end
end
