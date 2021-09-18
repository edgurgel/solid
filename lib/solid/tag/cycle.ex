defmodule Solid.Tag.Cycle do
  import NimbleParsec
  alias Solid.Parser.{BaseTag, Literal}

  @behaviour Solid.Tag

  @impl true
  def spec(_parser) do
    space = Literal.whitespace(min: 0)

    ignore(BaseTag.opening_tag())
    |> ignore(string("cycle"))
    |> ignore(space)
    |> optional(
      Literal.double_quoted_string()
      |> ignore(string(":"))
      |> ignore(space)
      |> unwrap_and_tag(:name)
    )
    |> concat(
      Literal.double_quoted_string()
      |> repeat(
        ignore(space)
        |> ignore(string(","))
        |> ignore(space)
        |> concat(Literal.double_quoted_string())
      )
      |> tag(:values)
    )
    |> ignore(BaseTag.closing_tag())
    |> tag(:cycle_exp)
  end

  @impl true
  def render([cycle_exp: cycle], context, _options) do
    {context, result} = Solid.Context.run_cycle(context, cycle)

    {[text: result], context}
  end
end
