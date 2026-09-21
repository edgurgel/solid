defmodule Solid.Text do
  @enforce_keys [:loc, :text]
  defstruct [:loc, :text]
  @type t :: %__MODULE__{loc: Solid.Parser.Loc.t(), text: binary}

  defimpl Solid.Renderable do
    def render(text, context, _options) do
      {text.text, context}
    end
  end

  defimpl Solid.Block do
    def blank?(text), do: Solid.Text.blank_text?(text.text)
  end

  @doc false
  @spec blank_text?(binary) :: boolean
  def blank_text?(<<c, rest::binary>>) when c in ~c" \n\r\t\f\v", do: blank_text?(rest)
  def blank_text?(<<>>), do: true
  def blank_text?(_), do: false
end
