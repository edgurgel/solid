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

    {[], %{context | vars: Map.put(context.vars, field_name, IO.iodata_to_binary(captured))}}
  end

  def render(
        [field: fields_name, result: result],
        context,
        options
      ) do
    {captured, context} = Solid.render(result, context, options)

    context_vars =
      put_in(
        context.vars,
        Enum.map(fields_name, &Access.key(&1, %{})),
        IO.iodata_to_binary(captured)
      )

    {[], %{context | vars: context_vars}}
  end
end
