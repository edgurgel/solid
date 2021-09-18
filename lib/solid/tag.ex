defmodule Solid.Tag do
  @moduledoc """
  This module define behaviour for tags.

  To implement new tag you need to create new module that implement the `Tag` behaviour:

      defmodule MyCustomTag do
        import NimbleParsec
        @behaviour Solid.Tag

        @impl true
        def spec(_parser) do
          space = Solid.Parser.Literal.whitespace(min: 0)

          ignore(string("{%"))
          |> ignore(space)
          |> ignore(string("my_tag"))
          |> ignore(space)
          |> ignore(string("%}"))
        end

        @impl true
        def render(_tag, _context, _options) do
          [text: "my first tag"]
        end
      end

  - `spec` define how to parse your tag
  - `render` define how to render your tag

  Then add the tag to your parser

      defmodule MyParser do
        use Solid.Parser.Base, custom_tags: [my_tag: MyCustomTag]
      end

  Then pass the custom parser as option

      "{% my_tag %}"
      |> Solid.parse!(parser: MyParser)
      |> Solid.render()

  Control flow tags can change the information Liquid shows using programming logic.

  More info: https://shopify.github.io/liquid/tags/control-flow/
  """

  alias Solid.Context

  @type rendered_data :: {:text, binary()} | {:object, keyword()} | {:tag, list()}

  @doc """
  Build and return `NimbleParsec` expression to parse your tag. There are some helper expressions that can be used:
  - `Solid.Parser.Literal`
  - `Solid.Parser.Variable`
  - `Solid.Parser.Argument`
  """

  @callback spec(module) :: NimbleParsec.t()

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
      text when is_binary(text) -> {[text: text], context}
      text -> {text, context}
    end
  end

  defp do_eval([], _context, _options), do: nil

  defp do_eval([{tag_module, tag_data}], context, options) do
    tag_module.render(tag_data, context, options)
  end
end
