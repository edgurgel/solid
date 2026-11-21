defmodule Solid.Inspect do
  @moduledoc false
  # Text form of maps and lists when they are output or used as strings:
  #
  #   %{"a" => 1, "b" => [nil, "x"]} -> {"a"=>1, "b"=>[nil, "x"]}
  #
  # Values inside a map or list are shown in their literal form: strings are
  # quoted and `nil` is shown as `nil`.

  @spec inspect(term) :: String.t()
  def inspect(value), do: value |> do_inspect() |> IO.iodata_to_binary()

  defp do_inspect(map) when is_map(map) and not is_struct(map) do
    pairs = Enum.map(map, fn {key, value} -> [do_inspect(key), "=>", do_inspect(value)] end)
    ["{", Enum.intersperse(pairs, ", "), "}"]
  end

  defp do_inspect(list) when is_list(list) do
    ["[", list |> Enum.map(&do_inspect/1) |> Enum.intersperse(", "), "]"]
  end

  defp do_inspect(float) when is_float(float), do: Solid.NumberHelper.float_to_string(float)

  defp do_inspect(struct) when is_struct(struct) do
    if String.Chars.impl_for(struct), do: to_string(struct), else: Kernel.inspect(struct)
  end

  defp do_inspect(value), do: Kernel.inspect(value)
end
