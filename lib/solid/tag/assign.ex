defmodule Solid.Tag.Assign do
  import NimbleParsec
  alias Solid.Parser.{Tag, Literal, Variable, Argument}

  @behaviour Solid.Tag

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

  @impl true
  def spec() do
    space = Literal.whitespace(min: 0)

    ignore(Tag.opening_tag())
    |> ignore(string("assign"))
    |> ignore(space)
    |> concat(Variable.field())
    |> ignore(space)
    |> ignore(string("="))
    |> ignore(space)
    |> tag(Argument.argument(), :argument)
    |> optional(tag(repeat(Argument.filter()), :filters))
    |> ignore(Tag.closing_tag())
    |> tag(:assign_exp)
  end
end
