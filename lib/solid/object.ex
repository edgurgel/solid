defmodule Solid.Object do
  @enforce_keys [:loc, :argument, :filters]
  defstruct [:loc, :argument, :filters]
  alias Solid.Parser.Loc
  alias Solid.{Argument, Filter, Lexer}

  @type t :: %__MODULE__{loc: Loc.t(), argument: Argument.t(), filters: [Filter]}

  @spec parse(Lexer.tokens()) :: {:ok, t, Lexer.tokens()} | {:error, binary, Lexer.loc()}
  def parse([{:end, meta}]) do
    # Let's use a null literal if the object is empty
    argument = %Solid.Literal{value: nil, loc: struct!(Loc, meta)}
    object = %__MODULE__{loc: struct!(Loc, meta), argument: argument, filters: []}
    {:ok, object, [{:end, meta}]}
  end

  def parse(tokens) do
    with {:ok, argument, filters, [{:end, _}] = rest} <- Argument.parse_with_filters(tokens) do
      object =
        %__MODULE__{
          loc: struct!(Loc, Solid.Parser.meta_head(tokens)),
          argument: argument,
          filters: filters
        }

      {:ok, object, rest}
    else
      {:ok, _argument, _filters, rest} ->
        {:error, "Unexpected token", Solid.Parser.meta_head(rest)}

      {:error, reason, meta} ->
        {:error, reason, meta}
    end
  end

  defimpl Solid.Renderable do
    def render(object, context, options) do
      {:ok, result, context} =
        Solid.Argument.render(object.argument, context, object.filters, options)

      {result, context}
    end
  end
end
