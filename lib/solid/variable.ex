defmodule Solid.Variable do
  alias Solid.Parser.Loc
  alias Solid.{AccessLiteral, AccessVariable}
  alias Solid.Literal

  @enforce_keys [:loc, :identifier, :accesses, :original_name]
  defstruct [:loc, :identifier, :accesses, :original_name]

  @type accesses :: [AccessVariable | AccessLiteral]
  @type t :: %__MODULE__{loc: Solid.Parser.Loc.t(), identifier: binary | nil, accesses: accesses}

  defimpl String.Chars do
    def to_string(variable), do: variable.original_name
  end

  @literals ~w(empty nil false true blank)

  @spec parse(Solid.Lexer.tokens()) ::
          {:ok, t | Literal.t(), Solid.Lexer.tokens()} | {:error, binary, Solid.Lexer.loc()}
  def parse(tokens) do
    case tokens do
      [{:identifier, meta, identifier} | rest] ->
        do_parse_identifier(identifier, meta, rest)

      [{:open_square, meta} | _] ->
        with {:ok, rest, accesses, accesses_original_name} <- access(tokens) do
          original_name = Enum.join(accesses_original_name)

          {:ok,
           %__MODULE__{
             loc: struct!(Loc, meta),
             identifier: nil,
             accesses: accesses,
             original_name: original_name
           }, rest}
        else
          {:error, _, meta} ->
            {:error, "Argument expected", meta}
        end

      _ ->
        {:error, "Variable expected", Solid.Parser.meta_head(tokens)}
    end
  end

  defp do_parse_identifier(identifier, meta, rest) do
    with {:ok, rest, accesses, accesses_original_name} <- access(rest) do
      if identifier in @literals and accesses == [] do
        {:ok, %Literal{loc: struct!(Loc, meta), value: literal(identifier)}, rest}
      else
        original_name = "#{identifier}" <> Enum.join(accesses_original_name)

        {:ok,
         %__MODULE__{
           loc: struct!(Loc, meta),
           identifier: identifier,
           accesses: accesses,
           original_name: original_name
         }, rest}
      end
    end
  end

  # Should return a literal ONLY if there is no access after. Must check if nil, true and false need this also
  defp literal(identifier) do
    case identifier do
      "nil" -> nil
      "true" -> true
      "false" -> false
      "empty" -> %Literal.Empty{}
      "blank" -> ""
    end
  end

  defp access(tokens, accesses \\ [], original_name \\ []) do
    case tokens do
      [{:open_square, _}, {:integer, meta, number}, {:close_square, _} | rest] ->
        access = %AccessLiteral{loc: struct!(Loc, meta), value: number}
        access(rest, [access | accesses], ["[#{number}]" | original_name])

      [{:open_square, _}, {:string, meta, string, quotes}, {:close_square, _} | rest] ->
        access = %AccessLiteral{loc: struct!(Loc, meta), value: string}
        quotes = IO.chardata_to_string([quotes])
        access(rest, [access | accesses], ["[#{quotes}#{string}#{quotes}]" | original_name])

      [{:open_square, _}, {:identifier, meta, _identifier} | _] ->
        with {:ok, variable, [{:close_square, _} | rest]} <- parse(tl(tokens)) do
          access = %AccessVariable{loc: struct!(Loc, meta), variable: variable}
          access(rest, [access | accesses], ["[#{variable.original_name}]" | original_name])
        else
          {:ok, _, rest} ->
            {:error, "Argument access mal terminated", Solid.Parser.meta_head(rest)}

          error ->
            error
        end

      [{:dot, _}, {:identifier, meta, identifier} | rest] ->
        access = %AccessLiteral{loc: struct!(Loc, meta), value: identifier}
        access(rest, [access | accesses], [".#{identifier}" | original_name])

      [{:open_square, meta} | _rest] ->
        {:error, "Argument access expected", meta}

      _ ->
        {:ok, tokens, Enum.reverse(accesses), Enum.reverse(original_name)}
    end
  end
end
