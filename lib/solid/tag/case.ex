defmodule Solid.Tag.Case do
  import NimbleParsec
  alias Solid.Parser.{Argument, BaseTag, Literal}

  @behaviour Solid.Tag

  def when_join(whens) do
    for {:when, [value: value, result: result]} <- whens, into: %{} do
      {value, result}
    end
  end

  @impl true
  def spec(parser) do
    space = Literal.whitespace(min: 0)

    case_tag =
      ignore(BaseTag.opening_tag())
      |> ignore(string("case"))
      |> ignore(space)
      |> concat(Argument.argument())
      |> ignore(BaseTag.closing_tag())

    when_tag =
      ignore(BaseTag.opening_tag())
      |> ignore(string("when"))
      |> ignore(space)
      |> concat(Literal.value())
      |> ignore(BaseTag.closing_tag())
      |> tag(parsec({parser, :liquid_entry}), :result)
      |> tag(:when)

    tag(case_tag, :case_exp)
    # FIXME
    |> ignore(parsec({parser, :liquid_entry}))
    |> unwrap_and_tag(reduce(times(when_tag, min: 1), {__MODULE__, :when_join, []}), :whens)
    |> optional(tag(BaseTag.else_tag(parser), :else_exp))
    |> ignore(BaseTag.opening_tag())
    |> ignore(string("endcase"))
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render([{:case_exp, field} | [{:whens, when_map} | _]] = tag, context, _options) do
    result =
      when_map[
        Solid.Argument.get(field, context, allow_undefined?: Keyword.has_key?(tag, :else_exp))
      ]

    if result do
      result
    else
      tag[:else_exp][:result]
    end
  end
end
