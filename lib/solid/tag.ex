defmodule Solid.Tag do
  @moduledoc """
  This module define behaviour for tags.

  To implement new custom tag you need to create new module that implement `CustomTag` behaviour:

      defmodule MyCustomTag do
        import NimbleParsec
        @behaviour Solid.Tag

        @impl true
        def spec() do
          space = Solid.Parser.Literal.whitespace(min: 0)

          ignore(string("{%"))
          |> ignore(space)
          |> ignore(string("my_tag"))
          |> ignore(space)
          |> ignore(string("%}"))
        end

        @impl true
        def render(_context, _binding, _options) do
          [text: "my first tag"]
        end
      end

  - `spec` define how to parse your tag
  - `render` define how to render your tag

  Then add custom tag to your parser

      defmodule MyParser do
        use Solid.Parser.Base, custom_tags: [my_tag: MyCustomTag]
      end

  Then pass your tag to render function

      "{% my_tag %}"
      |> Solid.parse!(parser: MyParser)
      |> Solid.render(tags: %{"my_tag" => MyCustomTag})

  Control flow tags can change the information Liquid shows using programming logic.

  More info: https://shopify.github.io/liquid/tags/control-flow/
  """

  alias Solid.{Expression, Context}

  @type rendered_data :: {:text, binary()} | {:object, keyword()} | {:tag, list()}

  @doc """
  Build and return `NimbleParsec` expression to parse your tag. There are some helper expressions that can be used:
  - `Solid.Parser.Literal`
  - `Solid.Parser.Variable`
  - `Solid.Parser.Argument`
  """

  @callback spec() :: NimbleParsec.t()

  @doc """
  Define how to render your tag.
  Third argument are the options passed to `Solid.render/2`
  """

  @callback render(list(), Solid.Context.t(), keyword()) ::
              {list(rendered_data), Solid.Context.t()} | String.t()

  @doc """
  Basic custom tag spec that accepts optional arguments
  """
  @spec basic(String.t()) :: NimbleParsec.t()
  def basic(name) do
    import NimbleParsec
    space = Solid.Parser.Literal.whitespace(min: 0)

    ignore(Solid.Parser.BaseTag.opening_tag())
    |> ignore(string(name))
    |> ignore(space)
    |> tag(optional(Solid.Parser.Argument.arguments()), :arguments)
    |> ignore(Solid.Parser.BaseTag.closing_tag())
  end

  @doc """
  Evaluate a tag and return the condition that succeeded or nil
  """
  @spec eval(any, Context.t(), keyword()) :: {iolist | nil, Context.t()}
  def eval(tag, context, options) do
    case do_eval(tag, context, options) do
      {text, context} -> {text, context}
      text -> {text, context}
    end
  end

  defp do_eval([], _context, _options), do: nil

  defp do_eval([cycle_exp: _] = tag, context, options) do
    Solid.Tag.Cycle.render(tag, context, options)
  end

  defp do_eval([{:if_exp, exp} | _] = tag, context, _options) do
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

  defp do_eval([{:unless_exp, exp} | _] = tag, context, _options) do
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

  defp do_eval([{:case_exp, _} | _] = tag, context, options) do
    Solid.Tag.Case.render(tag, context, options)
  end

  defp do_eval([assign_exp: _] = tag, context, options) do
    Solid.Tag.Assign.render(tag, context, options)
  end

  defp do_eval([capture_exp: _] = tag, context, options) do
    Solid.Tag.Capture.render(tag, context, options)
  end

  defp do_eval([counter_exp: _counter_exp] = tag, context, options) do
    Solid.Tag.Counter.render(tag, context, options)
  end

  defp do_eval([break_exp: _] = tag, context, options) do
    Solid.Tag.Break.render(tag, context, options)
  end

  defp do_eval([continue_exp: _] = tag, context, options) do
    Solid.Tag.Continue.render(tag, context, options)
  end

  defp do_eval([for_exp: _] = tag, context, options) do
    Solid.Tag.For.render(tag, context, options)
  end

  defp do_eval([raw_exp: _] = tag, context, options) do
    Solid.Tag.Raw.render(tag, context, options)
  end

  defp do_eval([render_exp: _] = tag, context, options) do
    Solid.Tag.Render.render(tag, context, options)
  end

  defp do_eval([{custom_tag, tag_data}], context, options) do
    parser = Keyword.get(options, :parser, Solid.Parser)

    case parser.custom_tag_module(custom_tag) do
      {:ok, custom_tag_module} ->
        case custom_tag_module.render(tag_data, context, options) do
          {result, context} -> {result, context}
          text when is_binary(text) -> {[text: text], context}
        end

      _ ->
        raise ArgumentError
    end
  end

  defp eval_elsif({:elsif_exp, elsif_exp}, context) do
    eval_expression(elsif_exp[:expression], context)
  end

  defp eval_expression(exps, context), do: Expression.eval(exps, context)
end
