defmodule Solid do
  @moduledoc """
  Main module to interact with Solid

  iex> Solid.parse("{{ variable }}") |> elem(1) |> Solid.render(%{ "variable" => "value" }) |> to_string
  "value"
  """
  alias Solid.{Object, Tag, Context}

  defmodule Template do
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
  """
  @spec parse!(String.t(), Keyword.t()) :: %Template{} | no_return
  def parse!(text, opts \\ []) do
    case parse(text, opts) do
      {:ok, template} -> template
      {:error, template_error} -> raise template_error
    end
  end

  @doc """
  It renders the compiled template using a `hash` with vars
  """
  # @spec render(any, Map.t) :: iolist
  def render(template_or_text, values, options \\ [])

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
    {result, context} =
      Enum.reduce(text, {[], context}, fn entry, {acc, context} ->
        try do
          {result, context} = do_render(entry, context, options)
          {result, acc, context} = maybe_trim(entry, result, acc, context)
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

  defp maybe_trim({:text, _data}, result, acc, context) do
    result = maybe_trim_current(result, context)
    context = %{context | trim_next: false}
    {result, acc, context}
  end

  defp maybe_trim({:object, data}, result, acc, context) do
    trim_previous = Keyword.get(data, :trim_previous)
    acc = maybe_trim_previous(acc, trim_previous)

    result = maybe_trim_current(result, context)

    trim_next = Keyword.get(data, :trim_next)
    context = %{context | trim_next: trim_next}

    {result, acc, context}
  end

  defp maybe_trim({:tag, _data}, result, acc, context) do
    context = %{context | trim_next: false}
    {result, acc, context}
  end

  defp maybe_trim_current(result, context) do
    if context.trim_next do
      trim_leading(result)
    else
      result
    end
  end

  defp maybe_trim_previous(acc, false), do: acc
  defp maybe_trim_previous(acc = [], _), do: acc

  defp maybe_trim_previous([prev | tail], true) do
    trimmed_prev = trim_trailing(prev)
    [trimmed_prev | tail]
  end

  defp trim_trailing([value]) do
    [String.trim_trailing(value)]
  end

  defp trim_leading([value]) do
    [String.trim_leading(value)]
  end

  defp do_render({:text, string}, context, _options), do: {string, context}

  defp do_render({:object, object}, context, options) do
    object_text = Object.render(object, context, options)
    {object_text, context}
  end

  defp do_render({:tag, tag}, context, options) do
    {result, context} = Tag.eval(tag, context, options)

    if result do
      render(result, context, options)
    else
      {"", context}
    end
  end
end
