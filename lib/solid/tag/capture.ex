defmodule Solid.Tag.Capture do
  import NimbleParsec
  alias Solid.Parser.{BaseTag, Literal, Variable}

  @behaviour Solid.Tag

  @impl true
  def spec(parser) do
    space = Literal.whitespace(min: 0)

    ignore(BaseTag.opening_tag())
    |> ignore(string("capture"))
    |> ignore(space)
    |> concat(Variable.field())
    |> ignore(BaseTag.closing_tag())
    |> tag(parsec({parser, :liquid_entry}), :result)
    |> ignore(BaseTag.opening_tag())
    |> ignore(string("endcapture"))
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render(
        [field: [field_name], result: result],
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
end
