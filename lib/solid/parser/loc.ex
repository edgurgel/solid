defmodule Solid.Parser.Loc do
  @enforce_keys [:line, :column]
  defstruct [:line, :column]
  @type t :: %__MODULE__{line: pos_integer, column: pos_integer}

  @doc "Builds a Loc from a lexer loc map. Cheaper than `struct!/2` on hot paths."
  @spec new(Solid.Lexer.loc()) :: t
  def new(%{line: line, column: column}), do: %__MODULE__{line: line, column: column}
end
