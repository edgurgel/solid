defmodule Solid.Parser.Base do
  defmacro __using__(opts) do
    custom_tag_modules = Keyword.get(opts, :custom_tags, [])

    quote location: :keep, bind_quoted: [custom_tag_modules: custom_tag_modules] do
      import NimbleParsec
      alias Solid.Parser.{Literal, Variable, Argument}

      def custom_tag_module(tag_name) do
        module = Keyword.get(unquote(custom_tag_modules), tag_name)
        if module, do: {:ok, module}, else: {:error, :not_found}
      end

      defp when_join(whens) do
        for {:when, [value: value, result: result]} <- whens, into: %{} do
          {value, result}
        end
      end

      space = Literal.whitespace(min: 0)

      opening_object = string("{{")
      opening_wc_object = string("{{-")
      closing_object = string("}}")
      closing_wc_object = string("-}}")

      opening_tag = Solid.Parser.Tag.opening_tag()
      closing_tag = Solid.Parser.Tag.closing_tag()
      opening_wc_tag = string("{%-")

      closing_wc_object_and_whitespace =
        closing_wc_object
        |> concat(Literal.whitespace(min: 0))
        |> ignore()

      object =
        ignore(opening_object)
        # At this stage whitespace control has been handled as part of the liquid_entry
        |> ignore(optional(string("-")))
        |> ignore(space)
        |> lookahead_not(closing_object)
        |> tag(Argument.argument(), :argument)
        |> optional(tag(repeat(Argument.filter()), :filters))
        |> ignore(space)
        |> ignore(choice([closing_wc_object_and_whitespace, closing_object]))
        |> tag(:object)

      case_tag =
        ignore(opening_tag)
        |> ignore(space)
        |> ignore(string("case"))
        |> ignore(space)
        |> concat(Argument.argument())
        |> ignore(space)
        |> ignore(closing_tag)

      when_tag =
        ignore(opening_tag)
        |> ignore(space)
        |> ignore(string("when"))
        |> ignore(space)
        |> concat(Literal.value())
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

      defcombinatorp(:__argument_filter__, argument_filter)

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

      defcombinatorp(:__boolean_expression__, boolean_expression)

      if_tag =
        ignore(opening_tag)
        |> ignore(space)
        |> ignore(string("if"))
        |> tag(parsec(:__boolean_expression__), :expression)
        |> ignore(closing_tag)
        |> tag(parsec(:liquid_entry), :result)

      elsif_tag =
        ignore(opening_tag)
        |> ignore(space)
        |> ignore(string("elsif"))
        |> tag(parsec(:__boolean_expression__), :expression)
        |> ignore(closing_tag)
        |> tag(parsec(:liquid_entry), :result)
        |> tag(:elsif_exp)

      unless_tag =
        ignore(opening_tag)
        |> ignore(space)
        |> ignore(string("unless"))
        |> tag(parsec(:__boolean_expression__), :expression)
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

      range =
        ignore(string("("))
        |> unwrap_and_tag(choice([integer(min: 1), Variable.field()]), :first)
        |> ignore(string(".."))
        |> unwrap_and_tag(choice([integer(min: 1), Variable.field()]), :last)
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
        |> concat(Argument.argument())
        |> ignore(space)
        |> ignore(string("in"))
        |> ignore(space)
        |> tag(choice([Variable.field(), range]), :enumerable)
        |> ignore(space)
        |> unwrap_and_tag(for_parameters, :parameters)
        |> ignore(space)
        |> ignore(closing_tag)
        |> tag(parsec(:liquid_entry), :result)
        |> optional(tag(else_tag, :else_exp))
        |> ignore(opening_tag)
        |> ignore(string("endfor"))
        |> ignore(space)
        |> ignore(closing_tag)
        |> tag(:for_exp)

      end_raw_tag =
        opening_tag
        |> ignore(string("endraw"))
        |> ignore(closing_tag)

      raw_tag =
        ignore(opening_tag)
        |> ignore(string("raw"))
        |> ignore(closing_tag)
        |> repeat(lookahead_not(ignore(end_raw_tag)) |> utf8_char([]))
        |> ignore(end_raw_tag)
        |> tag(:raw_exp)

      cycle_tag =
        ignore(opening_tag)
        |> ignore(string("cycle"))
        |> ignore(space)
        |> optional(
          Literal.double_quoted_string()
          |> ignore(string(":"))
          |> ignore(space)
          |> unwrap_and_tag(:name)
        )
        |> concat(
          Literal.double_quoted_string()
          |> repeat(
            ignore(space)
            |> ignore(string(","))
            |> ignore(space)
            |> concat(Literal.double_quoted_string())
          )
          |> tag(:values)
        )
        |> ignore(closing_tag)
        |> tag(:cycle_exp)

      render_tag =
        ignore(opening_tag)
        |> ignore(space)
        |> ignore(string("render"))
        |> ignore(space)
        |> tag(Argument.argument(), :template)
        |> tag(
          optional(
            ignore(string(","))
            |> ignore(space)
            |> concat(Argument.named_arguments())
          ),
          :arguments
        )
        |> ignore(space)
        |> ignore(closing_tag)
        |> tag(:render_exp)

      base_tags = [
        Solid.Tag.Break.spec(),
        Solid.Tag.Continue.spec(),
        Solid.Tag.Counter.spec(),
        Solid.Tag.Comment.spec(),
        Solid.Tag.Assign.spec(),
        Solid.Tag.Capture.spec(),
        cond_if_tag,
        cond_unless_tag,
        cond_case_tag,
        for_tag,
        raw_tag,
        cycle_tag,
        render_tag
      ]

      custom_tags =
        if custom_tag_modules != [] do
          custom_tag_modules
          |> Enum.uniq()
          |> Enum.map(fn {tag_name, module} ->
            tag(module.spec(), tag_name)
          end)
        end

      all_tags = base_tags ++ (custom_tags || [])

      tags =
        choice(all_tags)
        |> tag(:tag)

      text =
        lookahead_not(
          choice([
            Literal.whitespace(min: 1)
            |> concat(opening_wc_object),
            Literal.whitespace(min: 1)
            |> concat(opening_wc_tag),
            opening_object,
            opening_tag
          ])
        )
        |> utf8_string([], 1)
        |> times(min: 1)
        |> reduce({Enum, :join, []})
        |> tag(:text)

      leading_whitespace =
        Literal.whitespace(min: 1)
        |> lookahead(choice([opening_wc_object, opening_wc_tag]))
        |> ignore()

      defcombinatorp(:liquid_entry, repeat(choice([object, tags, text, leading_whitespace])))

      defparsec(:parse, parsec(:liquid_entry) |> eos())
    end
  end
end
