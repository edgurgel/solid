defmodule CustomTags do
  defmodule CurrentLine do
    @enforce_keys [:loc]
    defstruct [:loc]

    @behaviour Solid.Tag

    @impl true
    def parse("current_line", loc, context) do
      with {:ok, [{:end, _}], context} <- Solid.Lexer.tokenize_tag_end(context) do
        {:ok, %__MODULE__{loc: loc}, context}
      end
    end

    defimpl Solid.Renderable do
      def render(tag, context, _options) do
        {to_string(tag.loc.line), context}
      end
    end
  end

  defmodule CurrentYear do
    @enforce_keys [:loc]
    defstruct [:loc]

    @behaviour Solid.Tag

    @impl true
    def parse("get_current_year", loc, context) do
      with {:ok, [{:end, _}], context} <- Solid.Lexer.tokenize_tag_end(context) do
        {:ok, %__MODULE__{loc: loc}, context}
      end
    end

    defimpl Solid.Renderable do
      def render(_tag, context, _options) do
        {[to_string(Date.utc_today().year)], context}
      end
    end
  end

  defmodule CustomBrackedWrappedTag do
    alias Solid.Parser

    @enforce_keys [:loc, :body]
    defstruct [:loc, :body]
    @behaviour Solid.Tag

    @impl true
    def parse("myblock", loc, context) do
      with {:ok, [{:end, _}], context} <- Solid.Lexer.tokenize_tag_end(context),
           {:ok, body, _tag, _tokens, context} <-
             Parser.parse_until(context, "endmyblock", "Expected endmyblock") do
        {:ok, %__MODULE__{loc: loc, body: body}, context}
      end
    end

    defimpl Solid.Renderable do
      def render(tag, context, _options) do
        {tag.body, context}
      end
    end
  end
end
