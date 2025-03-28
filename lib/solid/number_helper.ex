defmodule Solid.NumberHelper do
  @moduledoc false

  @spec to_integer(term) :: {:ok, integer} | {:error, binary}
  def to_integer(input) when is_integer(input), do: {:ok, input}

  def to_integer(input) do
    case Integer.parse(to_string(input)) do
      {integer, _} -> {:ok, integer}
      _ -> {:error, "invalid integer"}
    end
  end
end
