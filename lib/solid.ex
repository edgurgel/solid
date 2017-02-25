defmodule Solid do
  @moduledoc """
  Main module to interact with Solid

  iex> Solid.parse("{{ variable }}") |> Solid.render(%{ "variable" => "value" }) |> to_string
  "value"
  """
  alias Solid.{Argument, Filter, Tag}

  defmodule Context do
    defstruct vars: %{}
    @type t :: %Context{vars: Map.t}
  end

  @doc """
  It generates the compiled template
  """
  @spec parse(String.t) :: any
  def parse(text) do
    :solid_parser.parse(text)
  end

  @doc """
  It renders the compiled template using a `hash` with vars
  """
  @spec render(any, Map.t) :: iolist
  def render(text, hash \\ %{}) do
    context =%Context{vars: hash}
    do_render(text, context) |> elem(0)
  end

  defp do_render(text, context) do
    case text do
      [{:string, string}, []] ->
        {[string], context}
      [{:string, string}, [{:open_object, _}, {:text, tail}]] ->
        {text, context} = do_render(tail, context)
        {[string, "{{", text], context}
      [{:string, string}, [{:open_tag, _}, {:text, tail}]] ->
        {text, context} = do_render(tail, context)
        {[string, "{%", text], context}
      [{:string, string}, [{:tag, tag}, {:text, tail}]] ->
        {tag_text, context} = render_tag(tag, context)
        {tail_text, context} = do_render(tail, context)
        {[string, tag_text, tail_text], context}
      [{:string, string}, [{:object, object}, {:text, tail}]] ->
        object_text = render_object(object, context)
        {tail_text, context} = do_render(tail, context)
        {[string, object_text, tail_text], context}
    end
  end

  defp render_tag(tag, context) do
    {result, context} = Tag.eval(tag, context)
    if result do
      do_render(result, context)
    else
      {"", context}
    end
  end

  defp render_object([], _context), do: []
  defp render_object(object, context) when is_list(object) do
    argument = object[:argument]
    value    = Argument.get(argument, context)

    filters = object[:filters]
    value   = value |> apply_filters(filters, context)

    to_string(value)
  end

  defp apply_filters(input, nil, _), do: input
  defp apply_filters(input, [], _), do: input
  defp apply_filters(input, [{filter, args} | filters], context) do
    values = for arg <- args, do: Argument.get(arg, context)
    Filter.apply(filter, [input | values]) |> apply_filters(filters, context)
  end
end
