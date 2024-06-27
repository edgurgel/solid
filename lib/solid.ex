defmodule Solid do
  @doc """
  It sets up Solid with built-in matchers for basic types and creates local delegates to `render`,
  `render!`, `parse`, and `parse!` in your wrapper module.

  Use this macro to include Solid in your project with a default configuration.

  If you're not using the default configuration and wish to customise one or several of the basic
  matchers, refer to the documentation in the `Solid.Matcher.Builtins` module.

  Use the `:delegates` option to include only a subset of the delegates in your wrapper module. To
  exclude all delegates, pass `false` or the empty list.

  Use the `:nomatchers` option to exclude the bundled matchers.
  """
  @all_delegates [:render, :render!, :parse, :parse!]
  @type delegates :: :render | :render! | :parse | :parse!
  @type option :: {:delegates, list(delegates()) | boolean()} | {:nomatchers, any()}
  @type options :: list(option())
  @spec __using__(options()) :: Macro.t()
  defmacro __using__(options) do
    delegates =
      case Keyword.get(options, :delegates, @all_delegates) do
        true -> @all_delegates
        [_ | _] = v -> v
        _ -> []
      end

    matchers = not Keyword.has_key?(options, :nomatchers)

    quote do
      if unquote(matchers) do
        use Solid.Matcher.Builtins
      end

      if :render in unquote(delegates) do
        defdelegate render, to: Solid
      end

      if :render! in unquote(delegates) do
        defdelegate render!, to: Solid
      end

      if :parse in unquote(delegates) do
        defdelegate parse, to: Solid
      end

      if :parse! in unquote(delegates) do
        defdelegate parse!, to: Solid
      end
    end
  end

  @moduledoc """
  Main module to interact with Solid
  """
  alias Solid.{Object, Tag, Context}

  @type errors :: %Solid.UndefinedVariableError{} | %Solid.UndefinedFilterError{}

  defmodule Template do
    @type rendered_data :: {:text, iodata()} | {:object, keyword()} | {:tag, list()}
    @type t :: %__MODULE__{parsed_template: list(rendered_data())}

    @enforce_keys [:parsed_template]
    defstruct [:parsed_template]
  end

  defmodule TemplateError do
    defexception [:message, :line, :reason, :header]

    @impl true
    def exception([reason, line, header]) do
      %__MODULE__{
        message: "Reason: #{reason}, line: #{elem(line, 0)}, header: #{header}",
        reason: reason,
        line: line,
        header: header
      }
    end
  end

  defmodule RenderError do
    defexception [:message, :errors, :result]

    @impl true
    def message(exception) do
      "#{length(exception.errors)} error(s) found while rendering"
    end
  end

  @doc """
  It generates the compiled template

  This function returns `{:ok, template}` if successfully parses the template, `{:error, template_error}` otherwise

  # Options

  * `parser` - a custom parser module can be passed. See `Solid.Tag` for more information

  """
  @spec parse(String.t(), Keyword.t()) :: {:ok, %Template{}} | {:error, %TemplateError{}}
  def parse(text, opts \\ []) do
    parser = Keyword.get(opts, :parser, Solid.Parser)

    case parser.parse(text) do
      {:ok, result, _, _, _, _} ->
        {:ok, %Template{parsed_template: result}}

      {:error, reason, _, _, line, _} ->
        {:error, TemplateError.exception([reason, line, String.slice(text, 0..20)])}
    end
  end

  @doc """
  It generates the compiled template

  This function returns the compiled template or raises an error. Same options as `parse/2`
  """
  @spec parse!(String.t(), Keyword.t()) :: Template.t() | no_return
  def parse!(text, opts \\ []) do
    case parse(text, opts) do
      {:ok, template} -> template
      {:error, template_error} -> raise template_error
    end
  end

  @doc """
  It returns the rendered template or it raises an exception
  with the accumulated errors and a partial result

  See `render/3` for more details
  """
  @spec render!(Solid.Template.t(), map, Keyword.t()) :: iolist
  def render!(%Template{} = template, hash, options \\ []) do
    case render(template, hash, options) do
      {:ok, result} ->
        result

      {:error, errors, result} ->
        raise RenderError, errors: errors, result: result
    end
  end

  @doc """
  It renders the compiled template using a map with vars

  ## Options

  - `file_system`: a tuple of {FileSystemModule, options}. If this option is not specified, `Solid` uses `Solid.BlankFileSystem` which raises an error when the `render` tag is used. `Solid.LocalFileSystem` can be used or a custom module may be implemented. See `Solid.FileSystem` for more details.

  - `custom_filters`: a module name where additional filters are defined. The base filters (thos from `Solid.Filter`) still can be used, however, custom filters always take precedence.

  - `strict_variables`: if `true`, it collects an error when a variable is referenced in the template, but not given in the map

  - `strict_filters`: if `true`, it collects an error when a filter is referenced in the template, but not built-in or provided via `custom_filters`

  ## Example

      fs = Solid.LocalFileSystem.new("/path/to/template/dir/")
      Solid.render(template, vars, [file_system: {Solid.LocalFileSystem, fs}])
  """
  def render(template_or_text, values, options \\ [])

  @spec render(%Template{}, map, Keyword.t()) :: {:ok, iolist} | {:error, list(errors), iolist}
  @spec render(list, %Context{}, Keyword.t()) :: {iolist, %Context{}}
  def render(%Template{parsed_template: parsed_template}, hash, options) do
    context = %Context{counter_vars: hash}

    {result, context} = render(parsed_template, context, options)

    process_result(result, context)
  catch
    {exp, result, context} when exp in [:break_exp, :continue_exp] ->
      process_result(result, context)
  end

  def render(text, context = %Context{}, options) do
    {result, context} =
      Enum.reduce(text, {[], context}, fn entry, {acc, context} ->
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

  defp process_result(result, context) do
    if context.errors == [] do
      {:ok, result}
    else
      # Errors are accumulated by prepending to the errors list
      {:error, Enum.reverse(context.errors), result}
    end
  end

  defp do_render({:text, string}, context, _options), do: {string, context}

  defp do_render({:object, object}, context, options) do
    {:ok, object_text, context} = Object.render(object, context, options)
    {object_text, context}
  end

  defp do_render({:tag, tag}, context, options) do
    render_tag(tag, context, options)
  end

  defp render_tag(tag, context, options) do
    {result, context} = Tag.eval(tag, context, options)

    if result do
      render(result, context, options)
    else
      {"", context}
    end
  end
end
