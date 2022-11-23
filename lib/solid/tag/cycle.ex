defmodule Solid.Tag.Cycle do
  import NimbleParsec
  alias Solid.Parser.{BaseTag, Literal}

  @behaviour Solid.Tag

  @impl true
  def spec(_parser) do
    space = Literal.whitespace(min: 0)
    quoted = choice([Literal.double_quoted_string(), Literal.single_quoted_string()])

    ignore(BaseTag.opening_tag())
    |> ignore(string("cycle"))
    |> ignore(space)
    |> optional(
      quoted
      |> ignore(string(":"))
      |> ignore(space)
      |> unwrap_and_tag(:name)
    )
    |> concat(
      quoted
      |> repeat(
        ignore(space)
        |> ignore(string(","))
        |> ignore(space)
        |> concat(quoted)
      )
      |> tag(:values)
    )
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render(cycle, context, _options) do
    {context, result} = Solid.Context.run_cycle(context, cycle)

    {[text: result], context}
  end
end
