defmodule Solid do
  @moduledoc """
  Main module to interact with Solid

  iex> Solid.parse("{{ variable }}") |> Solid.render(%{ "variable" => "value" }) |> to_string
  "value"
  """
  alias Solid.{Argument, Filter, Expression}

  @doc """
  It generates the compiled template
  """
  @spec parse(String.t) :: any
  def parse(text) do
    :solid_parser.parse(text)
  end

  @doc """
  It renders the compiled template using a `hash` with variables
  """
  @spec render(any, Map.t) :: iolist
  def render(text, hash \\ %{}) do
    case text do
      [{:string, string}, []] ->
        [string]
      [{:string, string}, [{:open_object, _}, {:text, tail}]] ->
        [string, "{{", render(tail, hash)]
      [{:string, string}, [{:open_tag, _}, {:text, tail}]] ->
        [string, "{%", render(tail, hash)]
      [{:string, string}, [{:tag, tag}, {:text, tail}]] ->
        [string, render_tag(tag, hash), render(tail)]
      [{:string, string}, [{:object, object}, {:text, tail}]] ->
        [string, render_object(object, hash), render(tail)]
    end
  end

  defp render_tag([], _hash), do: []
  defp render_tag(tag, hash) when is_list(tag) do
    if eval_expression(tag[:expression], hash) do
      render(tag[:text], hash)
    else
      ""
    end
  end

  defp render_object([], _hash), do: []
  defp render_object(object, hash) when is_list(object) do
    argument = object[:argument]
    value    = Argument.get(argument, hash)

    filters = object[:filters]
    value   = value |> apply_filters(filters, hash)

    to_string(value)
  end

  defp eval_expression(bool, _hash) when is_boolean(bool), do: bool
  defp eval_expression([arg1, op, arg2], hash) do
    v1 = Argument.get(arg1, hash)
    v2 = Argument.get(arg2, hash)
    Expression.eval(v1, op, v2)
  end

  defp apply_filters(input, nil, _), do: input
  defp apply_filters(input, [], _), do: input
  defp apply_filters(input, [{filter, args} | filters], hash) do
    values = for arg <- args, do: Argument.get(arg, hash)
    apply(Filter, String.to_existing_atom(filter), [input | values]) |> apply_filters(filters, hash)
  end
end
