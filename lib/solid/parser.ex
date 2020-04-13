defmodule Solid.Parser do
  import NimbleParsec

  defp when_join(whens) do
    for {:when, [value: value, result: result]} <- whens, into: %{} do
      {value, result}
    end
  end

  identifier = ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-], min: 1)

  plus = string("+")
  minus = string("-")

  true_value =
    string("true")
    |> replace(true)

  false_value =
    string("false")
    |> replace(false)

  null =
    string("nil")
    |> replace(nil)

  int =
    optional(minus)
    |> concat(integer(min: 1))
    |> reduce({Enum, :join, [""]})
    |> map({String, :to_integer, []})

  frac =
    string(".")
    |> concat(integer(min: 1))

  exp =
    choice([string("e"), string("E")])
    |> optional(choice([plus, minus]))
    |> integer(min: 1)

  float =
    int
    |> concat(frac)
    |> optional(exp)
    |> reduce({Enum, :join, [""]})
    |> map({String, :to_float, []})

  single_quoted_string =
    ignore(string(~s(')))
    |> repeat(
      lookahead_not(ascii_char([?']))
      |> choice([string(~s(\')), utf8_char([])])
    )
    |> ignore(string(~s(')))
    |> reduce({List, :to_string, []})

  double_quoted_string =
    ignore(string(~s(")))
    |> repeat(
      lookahead_not(ascii_char([?"]))
      |> choice([string(~s(\")), utf8_char([])])
    )
    |> ignore(string(~s(")))
    |> reduce({List, :to_string, []})

  bracket_access =
    ignore(string("["))
    |> choice([int, single_quoted_string, double_quoted_string])
    |> ignore(string("]"))

  dot_access =
    ignore(string("."))
    |> concat(identifier)

  field =
    identifier
    |> repeat(choice([dot_access, bracket_access]))
    |> tag(:field)

  value =
    choice([float, int, true_value, false_value, null, single_quoted_string, double_quoted_string])
    |> unwrap_and_tag(:value)

  argument = choice([value, field])

  opening_object = string("{{")
  closing_object = string("}}")

  opening_tag = string("{%")
  closing_tag = string("%}")

  space =
    string(" ")
    |> times(min: 0)

  text =
    lookahead_not(choice([opening_object, opening_tag]))
    |> utf8_string([], 1)
    |> times(min: 1)
    |> reduce({Enum, :join, []})
    |> tag(:text)

  filter_name =
    ascii_string([?a..?z, ?A..?Z], 1)
    |> concat(ascii_string([?a..?z, ?A..?Z, ?_], min: 0))
    |> reduce({Enum, :join, []})

  arguments =
    argument
    |> repeat(
      ignore(space)
      |> ignore(string(","))
      |> ignore(space)
      |> concat(argument)
    )

  filter =
    ignore(space)
    |> ignore(string("|"))
    |> ignore(space)
    |> concat(filter_name)
    |> tag(optional(ignore(string(":")) |> ignore(space) |> concat(arguments)), :arguments)
    |> tag(:filter)

  object =
    ignore(opening_object)
    |> ignore(space)
    |> lookahead_not(closing_object)
    |> tag(argument, :argument)
    |> optional(tag(repeat(filter), :filters))
    |> ignore(space)
    |> ignore(closing_object)
    |> tag(:object)

  comment = string("comment")

  end_comment = string("endcomment")

  comment_tag =
    ignore(opening_tag)
    |> ignore(space)
    |> ignore(comment)
    |> ignore(space)
    |> ignore(closing_tag)
    |> ignore(parsec(:liquid_entry))
    |> ignore(opening_tag)
    |> ignore(space)
    |> ignore(end_comment)
    |> ignore(space)
    |> ignore(closing_tag)

  increment =
    string("increment")
    |> replace({1, 0})

  decrement =
    string("decrement")
    |> replace({-1, -1})

  counter_tag =
    ignore(opening_tag)
    |> ignore(space)
    |> concat(choice([increment, decrement]))
    |> ignore(space)
    |> concat(field)
    |> ignore(space)
    |> ignore(closing_tag)
    |> tag(:counter_exp)

  case_tag =
    ignore(opening_tag)
    |> ignore(space)
    |> ignore(string("case"))
    |> ignore(space)
    |> concat(argument)
    |> ignore(space)
    |> ignore(closing_tag)

  when_tag =
    ignore(opening_tag)
    |> ignore(space)
    |> ignore(string("when"))
    |> ignore(space)
    |> concat(value)
    |> ignore(space)
    |> ignore(closing_tag)
    |> tag(parsec(:liquid_entry), :result)
    |> tag(:when)

  else_tag =
    ignore(opening_tag)
    |> ignore(space)
    |> ignore(string("else"))
    |> ignore(space)
    |> ignore(closing_tag)
    |> tag(parsec(:liquid_entry), :result)

  cond_case_tag =
    tag(case_tag, :case_exp)
    # FIXME
    |> ignore(parsec(:liquid_entry))
    |> unwrap_and_tag(reduce(times(when_tag, min: 1), :when_join), :whens)
    |> optional(tag(else_tag, :else_exp))
    |> ignore(opening_tag)
    |> ignore(space)
    |> ignore(string("endcase"))
    |> ignore(space)
    |> ignore(closing_tag)

  operator =
    choice([
      string("=="),
      string("!="),
      string(">="),
      string("<="),
      string(">"),
      string("<"),
      string("contains"),
      string("excludes")
    ])
    |> map({:erlang, :binary_to_atom, [:utf8]})

  boolean_operation =
    tag(argument, :arg1)
    |> ignore(space)
    |> tag(operator, :op)
    |> ignore(space)
    |> tag(argument, :arg2)
    |> wrap()

  expression =
    ignore(space)
    |> choice([boolean_operation, argument])
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

  if_tag =
    ignore(opening_tag)
    |> ignore(space)
    |> ignore(string("if"))
    |> tag(boolean_expression, :expression)
    |> ignore(closing_tag)
    |> tag(parsec(:liquid_entry), :result)

  elsif_tag =
    ignore(opening_tag)
    |> ignore(space)
    |> ignore(string("elsif"))
    |> tag(boolean_expression, :expression)
    |> ignore(closing_tag)
    |> tag(parsec(:liquid_entry), :result)
    |> tag(:elsif_exp)

  unless_tag =
    ignore(opening_tag)
    |> ignore(space)
    |> ignore(string("unless"))
    |> tag(boolean_expression, :expression)
    |> ignore(space)
    |> ignore(closing_tag)
    |> tag(parsec(:liquid_entry), :result)

  cond_if_tag =
    tag(if_tag, :if_exp)
    |> tag(times(elsif_tag, min: 0), :elsif_exps)
    |> optional(tag(else_tag, :else_exp))
    |> ignore(opening_tag)
    |> ignore(space)
    |> ignore(string("endif"))
    |> ignore(space)
    |> ignore(closing_tag)

  cond_unless_tag =
    tag(unless_tag, :unless_exp)
    |> tag(times(elsif_tag, min: 0), :elsif_exps)
    |> optional(tag(else_tag, :else_exp))
    |> ignore(opening_tag)
    |> ignore(space)
    |> ignore(string("endunless"))
    |> ignore(space)
    |> ignore(closing_tag)

  assign_tag =
    ignore(opening_tag)
    |> ignore(space)
    |> ignore(string("assign"))
    |> ignore(space)
    |> concat(field)
    |> ignore(space)
    |> ignore(string("="))
    |> ignore(space)
    |> concat(argument)
    |> ignore(space)
    |> ignore(closing_tag)
    |> tag(:assign_exp)

  range =
    ignore(string("("))
    |> unwrap_and_tag(choice([integer(min: 1), field]), :first)
    |> ignore(string(".."))
    |> unwrap_and_tag(choice([integer(min: 1), field]), :last)
    |> ignore(string(")"))
    |> tag(:range)

  limit =
    ignore(string("limit"))
    |> ignore(space)
    |> ignore(string(":"))
    |> ignore(space)
    |> unwrap_and_tag(integer(min: 1), :limit)
    |> ignore(space)

  offset =
    ignore(string("offset"))
    |> ignore(space)
    |> ignore(string(":"))
    |> ignore(space)
    |> unwrap_and_tag(integer(min: 1), :offset)
    |> ignore(space)

  reversed =
    string("reversed")
    |> replace({:reversed, 0})
    |> ignore(space)

  for_parameters =
    repeat(choice([limit, offset, reversed]))
    |> reduce({Enum, :into, [%{}]})

  for_tag =
    ignore(opening_tag)
    |> ignore(space)
    |> ignore(string("for"))
    |> ignore(space)
    |> concat(argument)
    |> ignore(space)
    |> ignore(string("in"))
    |> ignore(space)
    |> tag(choice([field, range]), :enumerable)
    |> ignore(space)
    |> unwrap_and_tag(for_parameters, :parameters)
    |> ignore(space)
    |> ignore(closing_tag)
    |> tag(parsec(:liquid_entry), :result)
    |> optional(tag(else_tag, :else_exp))
    |> ignore(opening_tag)
    |> ignore(space)
    |> ignore(string("endfor"))
    |> ignore(space)
    |> ignore(closing_tag)
    |> tag(:for_exp)

  capture_tag =
    ignore(opening_tag)
    |> ignore(space)
    |> ignore(string("capture"))
    |> ignore(space)
    |> concat(field)
    |> ignore(space)
    |> ignore(space)
    |> ignore(closing_tag)
    |> tag(parsec(:liquid_entry), :result)
    |> ignore(opening_tag)
    |> ignore(space)
    |> ignore(string("endcapture"))
    |> ignore(space)
    |> ignore(closing_tag)
    |> tag(:capture_exp)

  break_tag =
    ignore(opening_tag)
    |> ignore(space)
    |> ignore(string("break"))
    |> ignore(space)
    |> ignore(closing_tag)
    |> tag(:break_exp)

  continue_tag =
    ignore(opening_tag)
    |> ignore(space)
    |> ignore(string("continue"))
    |> ignore(space)
    |> ignore(closing_tag)
    |> tag(:continue_exp)

  end_raw_tag =
    opening_tag
    |> ignore(space)
    |> ignore(string("endraw"))
    |> ignore(space)
    |> ignore(closing_tag)

  raw_tag =
    ignore(opening_tag)
    |> ignore(space)
    |> ignore(string("raw"))
    |> ignore(space)
    |> ignore(closing_tag)
    |> repeat(lookahead_not(ignore(end_raw_tag)) |> utf8_char([]))
    |> ignore(end_raw_tag)
    |> tag(:raw_exp)

  cycle_tag =
    ignore(opening_tag)
    |> ignore(space)
    |> ignore(string("cycle"))
    |> ignore(space)
    |> optional(
      double_quoted_string
      |> ignore(string(":"))
      |> ignore(space)
      |> unwrap_and_tag(:name)
    )
    |> concat(
      double_quoted_string
      |> repeat(
        ignore(space)
        |> ignore(string(","))
        |> ignore(space)
        |> concat(double_quoted_string)
      )
      |> tag(:values)
    )
    |> ignore(space)
    |> ignore(closing_tag)
    |> tag(:cycle_exp)

  tags =
    choice([
      counter_tag,
      comment_tag,
      assign_tag,
      cond_if_tag,
      cond_unless_tag,
      cond_case_tag,
      for_tag,
      capture_tag,
      break_tag,
      continue_tag,
      raw_tag,
      cycle_tag
    ])
    |> tag(:tag)

  defcombinatorp(:liquid_entry, repeat(choice([object, tags, text])))

  defparsec(:parse, parsec(:liquid_entry) |> eos())
end
