defmodule Solid do
  @moduledoc """
  Main module to interact with Solid

  iex> Solid.parse("{{ variable }}") |> Solid.render(%{ "variable" => "value" }) |> to_string
  "value"
  """
  alias Solid.{Argument, Filter}

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
      [{:string, string}, [{:object, object}, {:text, tail}]] ->
        [string, render_object(object, hash), render(tail)]
    end
  end

  def render_object([], _hash), do: []
  def render_object(object, hash) when is_list(object) do
    argument = object[:argument]
    value    = Argument.get(argument, hash)

    filters = object[:filters]
    value   = value |> apply_filters(filters, hash)

    to_string(value)
  end

  defp apply_filters(input, nil, _), do: input
  defp apply_filters(input, [], _), do: input
  defp apply_filters(input, [{filter, args} | filters], hash) do
    values = for arg <- args, do: Argument.get(arg, hash)
    apply(Filter, String.to_existing_atom(filter), [input | values]) |> apply_filters(filters, hash)
  end
end
