defmodule Solid.AccessLiteral do
  @enforce_keys [:loc, :access_type, :value]
  defstruct [:loc, :access_type, :value]
  @type t :: %__MODULE__{loc: Solid.Parser.Loc.t(), access_type: :brackets | :dot, value: integer | binary}

  defimpl String.Chars do
    def to_string(access), do: inspect(access.value)
  end
end
