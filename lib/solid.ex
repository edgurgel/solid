defmodule Solid do
  @moduledoc """
  Solid is an implementation in Elixir of the [Liquid](https://shopify.github.io/liquid/) template language with
  strict parsing.
  """

  alias Solid.{Context, Object, Parser, Text}

  @type errors :: [error]
  @type error ::
          Solid.UndefinedVariableError.t()
          | Solid.UndefinedFilterError.t()
          | Solid.ArgumentError.t()
          | Solid.WrongFilterArityError.t()
          | Solid.FileSystem.Error.t()
          | Solid.RenderDepthError.t()
          | Solid.RenderCountError.t()
          | Solid.TemplateError.t()

  defmodule Template do
    @type t :: %__MODULE__{parsed_template: Parser.parse_tree(), tags: %{String.t() => module}}

    @enforce_keys [:parsed_template]
    defstruct [:parsed_template, tags: Solid.Tag.default_tags()]
  end

  defmodule RenderError do
    @type t :: %__MODULE__{message: binary, errors: Solid.errors(), result: iolist}
    defexception [:message, :errors, :result]

    @impl true
    def message(exception) do
      message = "#{length(exception.errors)} error(s) found while rendering"

      errors =
        exception.errors
        |> Enum.map(&Exception.message/1)
        |> Enum.join("\n")

      message <> "\n" <> errors
    end
  end

  defmodule ParserError do
    @type t :: %__MODULE__{
            reason: binary,
            meta: %{line: pos_integer, column: pos_integer},
            text: binary
          }
    defexception [:reason, :meta, :text]

    @impl true
    def message(%{text: text, reason: reason, meta: %{line: line, column: column}}) do
      line_size = String.length(to_string(line))
      "#{reason}\n#{line}: #{text}\n#{String.pad_leading("^", column + line_size + 2)}"
    end
  end

  defmodule TemplateError do
    @type t :: %__MODULE__{errors: [ParserError.t()]}
    defexception [:errors]

    @impl true
    def message(exception) do
      exception.errors
      |> Enum.map(&Exception.message/1)
      |> Enum.join("\n")
    end
  end

  @doc """
  It generates the compiled template

  This function returns the compiled template or raises an error. Same options as `parse/2`
  """
  def parse!(text, opts \\ []) do
    case parse(text, opts) do
      {:ok, template} -> template
      {:error, template_error} -> raise template_error
    end
  end

  @doc """
  It generates the compiled template

  This function returns `{:ok, template}` if successfully parses the template, `{:error, template_error}` otherwise

  # Options

  - `tags` - Override tags allowed during compilation. See `Solid.Tag.default_tags/0` for more information on the default set of tags
  - `filters_in_conditional_tags` - If `true`, enables filters inside `if`, `elsif`, and `unless` conditions (e.g. `{% if items | size > 0 %}`). Defaults to `false`. This diverges from the original Liquid specification which does not support filters in conditional tags.
  - `max_template_depth` - Maximum nested block depth allowed while parsing, or `:infinity` to allow any depth. Defaults to `100`. Parsing stops as soon as a template goes over the limit

  """
  @spec parse(binary, keyword) :: {:ok, Template.t()} | {:error, TemplateError.t()}
  def parse(text, opts \\ []) do
    with {:ok, parse_tree} <- Parser.parse(text, opts) do
      {:ok,
       %Template{
         parsed_template: parse_tree,
         tags: Keyword.get(opts, :tags, Solid.Tag.default_tags())
       }}
    else
      {:error, errors} ->
        lines = String.splitter(text, "\n")

        errors =
          Enum.map(errors, fn {reason, meta} ->
            %ParserError{text: Enum.at(lines, meta[:line] - 1), reason: reason, meta: meta}
          end)

        {:error, %TemplateError{errors: errors}}
    end
  end

  @doc """
  It renders the compiled template using a map with vars

  Same options as `render/3`
  """
  @spec render!(Template.t(), map, keyword) :: iolist | no_return
  def render!(%Template{} = template, hash, options \\ []) do
    case render(template, hash, options) do
      # Ignore errors here unless `strict_variables` or `strict_filters` are used
      {:ok, result, _error} ->
        result

      {:error, errors, result} ->
        raise RenderError, errors: errors, result: result
    end
  end

  @doc """
  It renders the compiled template using a map with initial vars

  ## Options

  - `file_system`: a tuple of {FileSystemModule, options}. If this option is not specified, `Solid` uses `Solid.BlankFileSystem` which returns an error when the `render` tag is used. `Solid.LocalFileSystem` can be used or a custom module may be implemented. See `Solid.FileSystem` for more details.

  - `custom_filters`: a module name where additional filters are defined. The base filters (those from `Solid.StandardFilter`) still can be used, however, custom filters always take precedence. May also be a function that receives the filter name and the arguments and must return `{:ok, term} | :error`.

  - `strict_variables`: if `true`, it collects an error when a variable is referenced in the template, but not given in the map

  - `strict_filters`: if `true`, it collects an error when a filter is referenced in the template, but not built-in or provided via `custom_filters`

  - `matcher_module`: a module to replace `Solid.Matcher` when resolving variables.

  - `max_render_depth`: maximum nested partial depth allowed for the `render` tag, or `:infinity` to allow any depth. Defaults to `100`. A partial that goes over the limit is not rendered and a `Solid.RenderDepthError` is collected instead

  - `max_render_count`: maximum number of partials the `render` tag may render in total, or `:infinity` for no limit. Defaults to `100_000`. The depth limit alone does not bound how much work a partial can trigger because partials that render more than one partial fan out exponentially. Going over the limit collects a `Solid.RenderCountError`

  Options are also used to parse partials read by the `render` tag, so parse options like
  `max_template_depth` apply to them as well.

  ## Example

  fs = Solid.LocalFileSystem.new("/path/to/template/dir/")
  Solid.render(template, vars, [file_system: {Solid.LocalFileSystem, fs}])
  """
  @spec render(Template.t(), map, keyword) ::
          {:ok, result :: iolist, errors} | {:error, errors, partial_result :: iolist}
  @spec render(Parser.parse_tree(), Context.t(), keyword) :: {iolist, Context.t()}
  def render(template_or_text, values, options \\ [])

  def render(%Template{} = template, context = %Context{}, options) do
    {result, context} = render_template(template, context, options)

    process_result(result, context, options)
  end

  def render(%Template{} = template, hash, options) do
    matcher_module = Keyword.get(options, :matcher_module, Solid.Matcher)
    context = %Context{counter_vars: hash, matcher_module: matcher_module}

    render(template, context, options)
  end

  def render(text, context = %Context{}, options) do
    {result, context} =
      Enum.reduce(List.wrap(text), {[], context}, fn entry, {acc, context} ->
        try do
          {result, context} = do_render(entry, context, options)
          {[result | acc], context}
        catch
          {:break_exp, result, context} ->
            throw({:break_exp, Enum.reverse([result | acc]), context})

          {:continue_exp, result, context} ->
            throw({:continue_exp, Enum.reverse([result | acc]), context})
        end
      end)

    {Enum.reverse(result), context}
  end

  @doc """
  It renders the compiled template returning the resulting context

  Unlike `render/3` the context is returned instead of the collected errors, so state that must
  survive a nested render — like the number of partials rendered so far — is not lost. It is used
  by the `render` tag to render partials. Same options as `render/3`.
  """
  @spec render_template(Template.t(), Context.t(), keyword) :: {iolist, Context.t()}
  def render_template(
        %Template{parsed_template: parse_tree, tags: tags},
        %Context{} = context,
        options
      ) do
    matcher_module = Keyword.get(options, :matcher_module, Solid.Matcher)
    context = %{context | matcher_module: matcher_module, tags: tags}

    render(parse_tree, context, options)
  catch
    {exp, result, context} when exp in [:break_exp, :continue_exp] ->
      {result, context}
  end

  # Optimisation for object and text to avoid extra render calls
  defp do_render(renderable, context, options)
       when is_struct(renderable, Text) or is_struct(renderable, Object) do
    Solid.Renderable.render(renderable, context, options)
  end

  defp do_render(tag, context, options) when is_struct(tag) do
    {result, context} = Solid.Renderable.render(tag, context, options)

    render(result, context, options)
  end

  defp do_render(iolist, context, _options) do
    {iolist, context}
  end

  defp process_result(result, context, options) do
    if strict_errors?(context.errors, options) do
      {:error, Enum.reverse(context.errors), result}
    else
      {:ok, result, Enum.reverse(context.errors)}
    end
  end

  defp strict_errors?(errors, options) do
    variable_errors? = Enum.any?(errors, &match?(%Solid.UndefinedVariableError{}, &1))
    filter_errors? = Enum.any?(errors, &match?(%Solid.UndefinedFilterError{}, &1))

    (options[:strict_variables] == true && variable_errors?) ||
      (options[:strict_filters] == true && filter_errors?)
  end
end
