defmodule Solid.Range do
  @moduledoc """
  Range representation

  (first..last)
  (1..5)
  """
  alias Solid.Parser.Loc

  alias Solid.{Argument, Lexer}

  @type t :: %__MODULE__{
          loc: Loc.t(),
          start: Argument.t(),
          finish: Argument.t()
        }

  @enforce_keys [:loc, :start, :finish]
  defstruct [:loc, :start, :finish]

  defimpl String.Chars do
    def to_string(range) do
      "(#{range.start}..#{range.finish})"
    end
  end

  @spec parse(Lexer.tokens()) :: {:ok, t, Lexer.tokens()} | {:error, binary, Lexer.loc()}
  def parse(tokens) do
    with [{:open_round, meta} | tokens] <- tokens,
         {:ok, start, tokens} <- Argument.parse(tokens),
         [{:dot, _}, {:dot, _} | tokens] <- tokens,
         {:ok, finish, tokens} <- Argument.parse(tokens),
         [{:close_round, _} | tokens] <- tokens do
      {:ok, %__MODULE__{loc: struct!(Loc, meta), start: start, finish: finish}, tokens}
    else
      _ ->
        {:error, "Range expected", Solid.Parser.meta_head(tokens)}
    end
  end
end
