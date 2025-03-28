defmodule Solid.Parser.Loc do
  @enforce_keys [:line, :column]
  defstruct [:line, :column]
  @type t :: %__MODULE__{line: pos_integer, column: pos_integer}
end
