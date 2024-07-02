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
      ignore(parsec({BaseTag, :opening_tag}))
      |> ignore(string("if"))
      |> tag(parsec({__MODULE__, :__boolean_expression__}), :expression)
      |> ignore(parsec({BaseTag, :closing_tag}))
      |> tag(parsec({parser, :liquid_entry}), :result)

    elsif_tag =
      ignore(parsec({BaseTag, :opening_tag}))
      |> ignore(string("elsif"))
      |> tag(parsec({__MODULE__, :__boolean_expression__}), :expression)
      |> ignore(parsec({BaseTag, :closing_tag}))
      |> tag(parsec({parser, :liquid_entry}), :result)
      |> tag(:elsif_exp)

    unless_tag =
      ignore(parsec({BaseTag, :opening_tag}))
      |> ignore(string("unless"))
      |> tag(parsec({__MODULE__, :__boolean_expression__}), :expression)
      |> ignore(space)
      |> ignore(parsec({BaseTag, :closing_tag}))
      |> tag(parsec({parser, :liquid_entry}), :result)

    cond_if_tag =
      tag(if_tag, :if_exp)
      |> tag(times(elsif_tag, min: 0), :elsif_exps)
      |> optional(tag(BaseTag.else_tag(parser), :else_exp))
      |> ignore(parsec({BaseTag, :opening_tag}))
      |> ignore(string("endif"))
      |> ignore(parsec({BaseTag, :closing_tag}))

    cond_unless_tag =
      tag(unless_tag, :unless_exp)
      |> tag(times(elsif_tag, min: 0), :elsif_exps)
      |> optional(tag(BaseTag.else_tag(parser), :else_exp))
      |> ignore(parsec({BaseTag, :opening_tag}))
      |> ignore(string("endunless"))
      |> ignore(parsec({BaseTag, :closing_tag}))

    choice([cond_if_tag, cond_unless_tag])
  end

  @impl true
  def render([{:if_exp, exp} | _] = tag, context, options) do
    {result, context} = eval_expression(exp[:expression], context, options)
    if result, do: throw({:result, exp, context})

    context = eval_elsif_exps(tag[:elsif_exps], context, options)

    else_exp = tag[:else_exp]
    if else_exp, do: throw({:result, else_exp, context})
    {nil, context}
  catch
    {:result, result, context} -> {result[:result], context}
  end

  def render([{:unless_exp, exp} | _] = tag, context, options) do
    {result, context} = eval_expression(exp[:expression], context, options)
    unless result, do: throw({:result, exp, context})

    context = eval_elsif_exps(tag[:elsif_exps], context, options)

    else_exp = tag[:else_exp]
    if else_exp, do: throw({:result, else_exp, context})
    {nil, context}
  catch
    {:result, result, context} -> {result[:result], context}
  end

  defp eval_elsif_exps(nil, context, _options), do: context

  defp eval_elsif_exps(elsif_exps, context, options) do
    {result, context} = eval_elsifs(elsif_exps, context, options)
    if result, do: throw({:result, elem(result, 1), context})
    context
  end

  defp eval_elsifs(elsif_exps, context, options) do
    Enum.reduce_while(elsif_exps, {nil, context}, fn {:elsif_exp, elsif_exp}, {nil, context} ->
      {result, context} = eval_expression(elsif_exp[:expression], context, options)

      if result do
        {:halt, {{:elsif_exp, elsif_exp}, context}}
      else
        {:cont, {nil, context}}
      end
    end)
  end

  defp eval_expression(exps, context, options), do: Expression.eval(exps, context, options)
end
