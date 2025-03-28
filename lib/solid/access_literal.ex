defmodule Solid.AccessLiteral do
  @enforce_keys [:loc, :value]
  defstruct [:loc, :value]
  @type t :: %__MODULE__{loc: Solid.Parser.Loc.t(), value: integer | binary}

  defimpl String.Chars do
    def to_string(access), do: inspect(access.value)
  end
end
