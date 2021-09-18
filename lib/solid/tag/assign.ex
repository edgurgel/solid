defmodule Solid.Tag.Assign do
  import NimbleParsec
  alias Solid.Parser.{BaseTag, Literal, Variable, Argument}

  @behaviour Solid.Tag

  @impl true
  def spec(_parser) do
    space = Literal.whitespace(min: 0)

    ignore(BaseTag.opening_tag())
    |> ignore(string("assign"))
    |> ignore(space)
    |> concat(Variable.field())
    |> ignore(space)
    |> ignore(string("="))
    |> ignore(space)
    |> tag(Argument.argument(), :argument)
    |> optional(tag(repeat(Argument.filter()), :filters))
    |> ignore(BaseTag.closing_tag())
    |> tag(:assign_exp)
  end

  @impl true
  def render(
        [assign_exp: [field: [field_name], argument: argument, filters: filters]],
        context,
        _options
      ) do
    new_value = Solid.Argument.get(argument, context, filters: filters)

    context = %{context | vars: Map.put(context.vars, field_name, new_value)}

    {nil, context}
  end
end
