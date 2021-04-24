defmodule Solid.Parser.Base do
  defmacro __using__(opts) do
    custom_tags = Keyword.get(opts, :custom_tags, [])

    quote do
      import NimbleParsec

      defp when_join(whens) do
        # TODO: Do we need to care about trims here? At which point would we process them?
        for {:when, mapping} <- whens, into: %{} do
          {Keyword.get(mapping, :value), Keyword.get(mapping, :result)}
        end
      end

      identifier = ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-, ??], min: 1)

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
        choice([
          float,
          int,
          true_value,
          false_value,
          null,
          single_quoted_string,
          double_quoted_string
        ])
        |> unwrap_and_tag(:value)

      argument = choice([value, field])

      non_trim_opening_tag = string("{%") |> replace(false) |> unwrap_and_tag(:trim_previous)

      opening_tags =
        choice([
          string("{%-") |> replace(true) |> unwrap_and_tag(:trim_previous),
          non_trim_opening_tag
        ])

      closing_tags =
        choice([
          string("-%}") |> replace(true) |> unwrap_and_tag(:trim_next),
          string("%}") |> replace(false) |> unwrap_and_tag(:trim_next)
        ])

      opening_objects =
        choice([
          string("{{-") |> replace(true) |> unwrap_and_tag(:trim_previous),
          string("{{") |> replace(false) |> unwrap_and_tag(:trim_previous)
        ])

      closing_objects =
        choice([
          string("-}}") |> replace(true) |> unwrap_and_tag(:trim_next),
          string("}}") |> replace(false) |> unwrap_and_tag(:trim_next)
        ])

      space =
        string(" ")
        |> times(min: 0)

      text =
        lookahead_not(choice([opening_objects, opening_tags]))
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
        opening_objects
        |> ignore(space)
        |> lookahead_not(closing_objects)
        |> tag(argument, :argument)
        |> optional(tag(repeat(filter), :filters))
        |> ignore(space)
        |> concat(closing_objects)
        |> tag(:object)

      comment = string("comment")

      end_comment = string("endcomment")

      comment_tag =
        opening_tags
        |> ignore(space)
        |> ignore(comment)
        |> ignore(space)
        |> ignore(closing_tags)
        |> ignore(parsec(:liquid_entry))
        |> ignore(opening_tags)
        |> ignore(space)
        |> ignore(end_comment)
        |> ignore(space)
        |> concat(closing_tags)
        |> tag(:comment)

      increment =
        string("increment")
        |> replace({1, 0})

      decrement =
        string("decrement")
        |> replace({-1, -1})

      counter_tag =
        opening_tags
        |> ignore(space)
        |> concat(choice([increment, decrement]))
        |> ignore(space)
        |> concat(field)
        |> ignore(space)
        |> concat(closing_tags)
        |> tag(:counter_exp)

      case_tag =
        opening_tags
        |> ignore(space)
        |> ignore(string("case"))
        |> ignore(space)
        |> concat(argument)
        |> ignore(space)
        |> concat(closing_tags)

      when_tag =
        opening_tags
        |> ignore(space)
        |> ignore(string("when"))
        |> ignore(space)
        |> concat(value)
        |> ignore(space)
        |> concat(closing_tags)
        |> tag(parsec(:liquid_entry), :result)
        |> tag(:when)

      else_tag =
        ignore(opening_tags)
        |> ignore(space)
        |> ignore(string("else"))
        |> ignore(space)
        # TODO: Add custom trim tag for else body?
        |> concat(closing_tags)
        |> tag(parsec(:liquid_entry), :result)

      cond_case_tag =
        tag(case_tag, :case_exp)
        # FIXME
        |> ignore(parsec(:liquid_entry))
        |> unwrap_and_tag(reduce(times(when_tag, min: 1), :when_join), :whens)
        |> optional(tag(else_tag, :else_exp))
        |> concat(opening_tags)
        |> ignore(space)
        |> ignore(string("endcase"))
        |> ignore(space)
        |> concat(closing_tags)

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
        |> map({:erlang, :binary_to_existing_atom, [:utf8]})

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
        opening_tags
        |> ignore(space)
        |> ignore(string("if"))
        |> tag(boolean_expression, :expression)
        # TODO: Add custom trim tag for if body?
        |> concat(closing_tags)
        |> tag(parsec(:liquid_entry), :result)

      elsif_tag =
        ignore(opening_tags)
        |> ignore(space)
        |> ignore(string("elsif"))
        |> tag(boolean_expression, :expression)
        # TODO: Add custom trim tag for elsif body?
        |> concat(closing_tags)
        |> tag(parsec(:liquid_entry), :result)
        |> tag(:elsif_exp)

      unless_tag =
        opening_tags
        |> ignore(space)
        |> ignore(string("unless"))
        |> tag(boolean_expression, :expression)
        |> ignore(space)
        # TODO: Add custom trim tag for unless body?
        |> concat(closing_tags)
        |> tag(parsec(:liquid_entry), :result)

      cond_if_tag =
        tag(if_tag, :if_exp)
        |> tag(times(elsif_tag, min: 0), :elsif_exps)
        |> optional(tag(else_tag, :else_exp))
        |> concat(opening_tags)
        |> ignore(space)
        |> ignore(string("endif"))
        |> ignore(space)
        |> concat(closing_tags)

      cond_unless_tag =
        tag(unless_tag, :unless_exp)
        |> tag(times(elsif_tag, min: 0), :elsif_exps)
        |> optional(tag(else_tag, :else_exp))
        |> concat(opening_tags)
        |> ignore(space)
        |> ignore(string("endunless"))
        |> ignore(space)
        |> concat(closing_tags)

      assign_tag =
        opening_tags
        |> ignore(space)
        |> ignore(string("assign"))
        |> ignore(space)
        |> concat(field)
        |> ignore(space)
        |> ignore(string("="))
        |> ignore(space)
        |> tag(argument, :argument)
        |> optional(tag(repeat(filter), :filters))
        |> ignore(space)
        |> concat(closing_tags)
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
        opening_tags
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
        |> concat(closing_tags)
        |> tag(parsec(:liquid_entry), :result)
        |> optional(tag(else_tag, :else_exp))
        |> concat(opening_tags)
        |> ignore(space)
        |> ignore(string("endfor"))
        |> ignore(space)
        |> concat(closing_tags)
        |> tag(:for_exp)

      capture_tag =
        opening_tags
        |> ignore(space)
        |> ignore(string("capture"))
        |> ignore(space)
        |> concat(field)
        |> ignore(space)
        |> ignore(space)
        |> concat(closing_tags)
        |> tag(parsec(:liquid_entry), :result)
        |> concat(opening_tags)
        |> ignore(space)
        |> ignore(string("endcapture"))
        |> ignore(space)
        |> concat(closing_tags)
        |> tag(:capture_exp)

      break_tag =
        opening_tags
        |> ignore(space)
        |> ignore(string("break"))
        |> ignore(space)
        |> concat(closing_tags)
        |> tag(:break_exp)

      continue_tag =
        opening_tags
        |> ignore(space)
        |> ignore(string("continue"))
        |> ignore(space)
        |> concat(closing_tags)
        |> tag(:continue_exp)

      # NOTE: For most tags Liquid does allow whitespace controll for the previous element even if this will result in a no-op (see comment tag).
      # However, for some reason it's not valid for endraw tags.
      # See: https://github.com/Shopify/liquid/issues/1430
      end_raw_tag =
        ignore(non_trim_opening_tag)
        |> ignore(space)
        |> ignore(string("endraw"))
        |> ignore(space)
        |> ignore(closing_tags)

      raw_tag =
        opening_tags
        |> ignore(space)
        |> ignore(string("raw"))
        |> ignore(space)
        # NOTE: Liquid only uses the raw tag to controll whitespace for before and after the whole raw tag block.
        # TODO: MAKE SURE WE DO NOT TRUNCATE THE RAW TEXT INSIDE!
        |> concat(closing_tags)
        |> repeat(lookahead_not(ignore(end_raw_tag)) |> utf8_char([]))
        |> ignore(end_raw_tag)
        |> tag(:raw_exp)

      cycle_tag =
        opening_tags
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
        |> concat(closing_tags)
        |> tag(:cycle_exp)

      base_tags = [
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
      ]

      # We must try to parse longer strings first so if
      # foo and foobar are custom tags foobar must be tried to be parsed first
      custom_tags =
        unquote(custom_tags)
        |> Enum.uniq()
        |> Enum.sort_by(&String.length/1, &Kernel.>=/2)
        |> Enum.map(fn custom_tag -> string(custom_tag) end)

      all_tags =
        if custom_tags != [] do
          custom_tag =
            opening_tags
            |> ignore(space)
            |> concat(choice(custom_tags))
            |> ignore(space)
            |> tag(optional(arguments), :arguments)
            |> ignore(space)
            |> concat(closing_tags)
            |> tag(:custom_tag)

          base_tags ++ [custom_tag]
        else
          base_tags
        end

      tags =
        choice(all_tags)
        |> tag(:tag)

      defcombinatorp(:liquid_entry, repeat(choice([object, tags, text])))

      defparsec(:parse, parsec(:liquid_entry) |> eos())
    end
  end
end

defmodule Solid.Parser do
  use Solid.Parser.Base
end
