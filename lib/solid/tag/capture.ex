defmodule Solid.Tag.Capture do
  import NimbleParsec
  alias Solid.Parser.{Tag, Literal, Variable}

  @behaviour Solid.Tag

  @impl true
  def render(
        [capture_exp: [field: [field_name], result: result]],
        context,
        options
      ) do
    {captured, context} = Solid.render(result, context, options)

    context = %{
      context
      | vars: Map.put(context.vars, field_name, IO.iodata_to_binary(captured))
    }

    {nil, context}
  end

  @impl true
  def spec() do
    space = Literal.whitespace(min: 0)

    ignore(Tag.opening_tag())
    |> ignore(string("capture"))
    |> ignore(space)
    |> concat(Variable.field())
    |> ignore(Tag.closing_tag())
    |> tag(parsec(:liquid_entry), :result)
    |> ignore(Tag.opening_tag())
    |> ignore(string("endcapture"))
    |> ignore(Tag.closing_tag())
    |> tag(:capture_exp)
  end
end
