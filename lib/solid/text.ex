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
    def blank?(text) do
      String.trim(text.text) == ""
    end
  end
end
