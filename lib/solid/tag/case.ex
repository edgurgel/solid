defmodule Solid.Tag.Case do
  import NimbleParsec
  alias Solid.Parser.{Argument, BaseTag, Literal}

  @behaviour Solid.Tag

  def when_join(whens) do
    whens
    |> Enum.flat_map(fn {:when, values} ->
      values
      |> Enum.filter(fn {key, _} -> key == :value end)
      |> Enum.map(fn {_, val} -> {val, Keyword.get(values, :result)} end)
    end)
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

    when_condition =
      Argument.argument()
      |> repeat(
        ignore(space)
        |> ignore(choice([string(","), string("or")]))
        |> ignore(space)
        |> concat(Argument.argument())
      )

    when_tag =
      ignore(BaseTag.opening_tag())
      |> ignore(string("when"))
      |> ignore(space)
      |> concat(when_condition)
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
  def render([{:case_exp, field} | [{:whens, when_keyword} | _]] = tag, context, options) do
    {:ok, value, context} = Solid.Argument.get(field, context, options)

    result =
      case Enum.find(when_keyword, fn {keyfind, _} -> keyfind == value end) do
        {_, result} -> result
        _ -> nil
      end

    if result do
      {result, context}
    else
      {tag[:else_exp][:result], context}
    end
  end
end
