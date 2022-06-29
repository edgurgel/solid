defmodule Solid do
  @moduledoc """
  Main module to interact with Solid
  """
  alias Solid.{Object, Tag, Context}

  defmodule Template do
    @type t :: %__MODULE__{
            parsed_template: list(rendered_data())
          }

    @type rendered_data :: {:text, iolist() | String.t()} | {:object, keyword()} | {:tag, list()}
    @enforce_keys [:parsed_template]
    defstruct [:parsed_template]
  end

  defmodule TemplateError do
    defexception [:message, :line, :reason]

    @impl true
    def exception([reason, line]) do
      %__MODULE__{
        message: "Reason: #{reason}, line: #{elem(line, 0)}",
        reason: reason,
        line: line
      }
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
      {:ok, result, _, _, _, _} -> {:ok, %Template{parsed_template: result}}
      {:error, reason, _, _, line, _} -> {:error, TemplateError.exception([reason, line])}
    end
  end

  @doc """
  It generates the compiled template

  This function returns the compiled template or raises an error. Same options as `parse/2`
  """
  @spec parse!(String.t(), Keyword.t()) :: %Template{} | no_return
  def parse!(text, opts \\ []) do
    case parse(text, opts) do
      {:ok, template} -> template
      {:error, template_error} -> raise template_error
    end
  end

  @doc """
  It renders the compiled template using a map with vars

  **Options**
  - `file_system`: a tuple of {FileSystemModule, options}. If this option is not specified, `Solid` uses `Solid.BlankFileSystem` which raises an error when the `render` tag is used. `Solid.LocalFileSystem` can be used or a custom module may be implemented. See `Solid.FileSystem` for more details.

  - `custom_filters`: a module name where additional filters are defined. The base filters (thos from `Solid.Filter`) still can be used, however, custom filters always take precedence.

  **Example**:

  ```elixir
  fs = Solid.LocalFileSystem.new("/path/to/template/dir/")
  Solid.render(template, vars, [file_system: {Solid.LocalFileSystem, fs}])
  ```
  """
  def render(template_or_text, values, options \\ [])

  @spec render(%Template{}, map, Keyword.t()) :: iolist
  @spec render(list, %Context{}, Keyword.t()) :: {iolist, %Context{}}
  def render(%Template{parsed_template: parsed_template}, hash, options) do
    context = %Context{vars: hash}

    parsed_template
    |> render(context, options)
    |> elem(0)
  catch
    {:break_exp, partial_result, _context} ->
      partial_result

    {:continue_exp, partial_result, _context} ->
      partial_result
  end

  def render(text, context = %Context{}, options) do
    Solid.ErrorContext.new!()

    {result, context} =
      Enum.reduce(text, {[], context}, fn entry, {acc, context} ->
        try do
          {result, context} = do_render(entry, context, options)
          {[result | acc], context}
        catch
          {:break_exp, partial_result, context} ->
            throw({:break_exp, Enum.reverse([partial_result | acc]), context})

          {:continue_exp, partial_result, context} ->
            throw({:continue_exp, Enum.reverse([partial_result | acc]), context})
        end
      end)

    {Enum.reverse(result), context}
  end

  defp do_render({:text, string}, context, _options), do: {string, context}

  defp do_render({:object, object}, context, options) do
    object_text = Object.render(object, context, options)
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
