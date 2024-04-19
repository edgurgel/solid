defmodule Solid.Tag.Counter do
  import NimbleParsec
  alias Solid.Parser.{BaseTag, Literal, Variable}
  alias Solid.Argument

  @behaviour Solid.Tag

  @impl true
  def spec(_parser) do
    space = Literal.whitespace(min: 0)

    increment =
      string("increment")
      |> replace({1, 0})

    decrement =
      string("decrement")
      |> replace({-1, -1})

    ignore(BaseTag.opening_tag())
    |> concat(choice([increment, decrement]))
    |> ignore(space)
    |> concat(Variable.field())
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render([{operation, default}, field], context, options) do
    {:ok, value, context} = Argument.get([field], context, [{:scopes, [:counter_vars]} | options])
    value = value || default

    {:field, [field_name]} = field

    context = %{
      context
      | counter_vars: Map.put(context.counter_vars, field_name, value + operation)
    }

    {[text: to_string(value)], context}
  end
end
