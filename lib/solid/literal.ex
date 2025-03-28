defmodule Solid.Literal do
  alias Solid.Lexer
  alias Solid.Parser.Loc

  defmodule Empty do
    defstruct []
  end

  @enforce_keys [:loc, :value]
  defstruct [:loc, :value]

  @type value :: boolean | nil | binary | integer | float | %Empty{}
  @type t :: %__MODULE__{loc: Loc.t(), value: value}

  defimpl String.Chars do
    def to_string(literal), do: inspect(literal.value)
  end

  @spec parse(Lexer.tokens()) :: {:ok, t, Lexer.tokens()} | {:error, binary, Lexer.loc()}
  def parse(tokens) do
    case tokens do
      [{type, meta, value} | rest] when type in [:float, :integer] ->
        {:ok, %__MODULE__{loc: struct!(Loc, meta), value: value}, rest}

      [{:string, meta, value, _quotes} | rest] ->
        {:ok, %__MODULE__{loc: struct!(Loc, meta), value: value}, rest}

      _ ->
        {:error, "Literal expected", Solid.Parser.meta_head(tokens)}
    end
  end
end
