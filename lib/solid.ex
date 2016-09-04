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
  def render({:text, text} = template, hash \\ %{}) do
    case text do
      [{:string, string} | tail] -> [string | render_liquid(hd(tail), hash)]
    end
  end

  def render_liquid([], _hash), do: []
  def render_liquid(liquid, hash) when is_list(liquid) do
    argument = get_in(liquid, [:liquid, :argument])
    value    = Argument.get(argument, hash)

    filters = get_in(liquid, [:liquid, :filters])
    value  = value |> apply_filters(filters, hash)

    [to_string(value) | render(liquid[:text], hash)]
  end

  defp apply_filters(input, nil, _), do: input
  defp apply_filters(input, [], _), do: input
  defp apply_filters(input, [{filter, args} | filters], hash) do
    values = for arg <- args, do: Argument.get(arg, hash)
    apply(Filter, String.to_existing_atom(filter), [input | values]) |> apply_filters(filters, hash)
  end
end
