defmodule Solid.ParserContext do
  alias Solid.Lexer

  @default_max_depth 100

  @type max_depth :: pos_integer | :infinity

  @type t :: %__MODULE__{
          rest: binary,
          line: Lexer.line(),
          column: Lexer.column(),
          mode: :normal | :liquid_tag,
          depth: non_neg_integer(),
          max_depth: max_depth,
          tags: %{String.t() => module} | nil,
          opts: keyword
        }

  @enforce_keys [:rest, :line, :column, :mode]
  defstruct [
    :rest,
    :line,
    :column,
    :mode,
    depth: 0,
    max_depth: @default_max_depth,
    tags: nil,
    opts: []
  ]

  @doc "Maximum nested block depth allowed while parsing when not overridden"
  @spec default_max_depth() :: pos_integer
  def default_max_depth, do: @default_max_depth
end
