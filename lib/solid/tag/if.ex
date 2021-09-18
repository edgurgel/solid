defmodule Solid.Tag.If do
  @moduledoc """
  If and Unless tags
  """

  import NimbleParsec
  alias Solid.Parser.{Argument, BaseTag, Literal}
  alias Solid.Expression

  @behaviour Solid.Tag

  space = Literal.whitespace(min: 0)

  operator =
    choice([
      string("=="),
      string("!="),
      string(">="),
      string("<="),
      string(">"),
      string("<"),
      string("contains")
    ])
    |> map({:erlang, :binary_to_atom, [:utf8]})

  argument_filter =
    tag(Argument.argument(), :argument)
    |> tag(
      repeat(
        lookahead_not(choice([operator, string("and"), string("or")]))
        |> concat(Argument.filter())
      ),
      :filters
    )

  defcombinator(:__argument_filter__, argument_filter)

  boolean_operation =
    tag(parsec(:__argument_filter__), :arg1)
    |> ignore(space)
    |> tag(operator, :op)
    |> ignore(space)
    |> tag(parsec(:__argument_filter__), :arg2)
    |> wrap()

  expression =
    ignore(space)
    |> choice([boolean_operation, wrap(parsec(:__argument_filter__))])
    |> ignore(space)

  bool_and =
    string("and")
    |> replace(:bool_and)

  bool_or =
    string("or")
    |> replace(:bool_or)

  boolean_expression =
    expression
    |> repeat(choice([bool_and, bool_or]) |> concat(expression))

  defcombinator(:__boolean_expression__, boolean_expression)

  @impl true
  def spec(parser) do
    space = Literal.whitespace(min: 0)

    if_tag =
      ignore(BaseTag.opening_tag())
      |> ignore(string("if"))
      |> tag(parsec({__MODULE__, :__boolean_expression__}), :expression)
      |> ignore(BaseTag.closing_tag())
      |> tag(parsec({parser, :liquid_entry}), :result)

    elsif_tag =
      ignore(BaseTag.opening_tag())
      |> ignore(string("elsif"))
      |> tag(parsec({__MODULE__, :__boolean_expression__}), :expression)
      |> ignore(BaseTag.closing_tag())
      |> tag(parsec({parser, :liquid_entry}), :result)
      |> tag(:elsif_exp)

    unless_tag =
      ignore(BaseTag.opening_tag())
      |> ignore(string("unless"))
      |> tag(parsec({__MODULE__, :__boolean_expression__}), :expression)
      |> ignore(space)
      |> ignore(BaseTag.closing_tag())
      |> tag(parsec({parser, :liquid_entry}), :result)

    cond_if_tag =
      tag(if_tag, :if_exp)
      |> tag(times(elsif_tag, min: 0), :elsif_exps)
      |> optional(tag(BaseTag.else_tag(), :else_exp))
      |> ignore(BaseTag.opening_tag())
      |> ignore(string("endif"))
      |> ignore(BaseTag.closing_tag())

    cond_unless_tag =
      tag(unless_tag, :unless_exp)
      |> tag(times(elsif_tag, min: 0), :elsif_exps)
      |> optional(tag(BaseTag.else_tag(), :else_exp))
      |> ignore(BaseTag.opening_tag())
      |> ignore(string("endunless"))
      |> ignore(BaseTag.closing_tag())

    choice([cond_if_tag, cond_unless_tag])
  end

  @impl true
  def render([{:if_exp, exp} | _] = tag, context, _options) do
    if eval_expression(exp[:expression], context), do: throw({:result, exp})
    elsif_exps = tag[:elsif_exps]

    if elsif_exps do
      result = Enum.find(elsif_exps, &eval_elsif(&1, context))
      if result, do: throw({:result, elem(result, 1)})
    end

    else_exp = tag[:else_exp]
    if else_exp, do: throw({:result, else_exp})
  catch
    {:result, result} -> result[:result]
  end

  def render([{:unless_exp, exp} | _] = tag, context, _options) do
    unless eval_expression(exp[:expression], context), do: throw({:result, exp})
    elsif_exps = tag[:elsif_exps]

    if elsif_exps do
      result = Enum.find(elsif_exps, &eval_elsif(&1, context))
      if result, do: throw({:result, elem(result, 1)})
    end

    else_exp = tag[:else_exp]
    if else_exp, do: throw({:result, else_exp})
  catch
    {:result, result} -> result[:result]
  end

  defp eval_elsif({:elsif_exp, elsif_exp}, context) do
    eval_expression(elsif_exp[:expression], context)
  end

  defp eval_expression(exps, context), do: Expression.eval(exps, context)
end
