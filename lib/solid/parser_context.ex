defmodule Solid.ParserContext do
  alias Solid.Lexer

  @type t :: %__MODULE__{
          rest: binary,
          line: Lexer.line(),
          column: Lexer.column(),
          mode: :normal | :liquid_tag,
          tags: %{String.t() => module} | nil
        }

  @enforce_keys [:rest, :line, :column, :mode]
  defstruct [:rest, :line, :column, :mode, tags: nil]
end
