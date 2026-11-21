defmodule Solid.Tag do
  alias Solid.{Lexer, ParserContext, Renderable, Tags}
  alias Solid.Parser.Loc

  @callback parse(
              tag_name :: binary,
              Loc.t(),
              ParserContext.t()
            ) ::
              {:ok, Renderable.t(), ParserContext.t()}
              | {:error, reason :: binary, Lexer.loc()}
              | {:error, reason :: binary, rest :: binary, Lexer.loc()}

  def default_tags do
    %{
      "#" => Tags.InlineCommentTag,
      "assign" => Tags.AssignTag,
      "break" => Tags.BreakTag,
      "capture" => Tags.CaptureTag,
      "case" => Tags.CaseTag,
      "comment" => Tags.CommentTag,
      "continue" => Tags.ContinueTag,
      "cycle" => Tags.CycleTag,
      "decrement" => Tags.CounterTag,
      "echo" => Tags.EchoTag,
      "for" => Tags.ForTag,
      "if" => Tags.IfTag,
      "increment" => Tags.CounterTag,
      "raw" => Tags.RawTag,
      "render" => Tags.RenderTag,
      "unless" => Tags.IfTag,
      "tablerow" => Tags.TablerowTag
    }
  end

  @spec parse(tag_name :: binary, Loc.t(), ParserContext.t()) ::
          {:ok, Renderable.t(), ParserContext.t()}
          | {:error, reason :: binary, Lexer.loc()}
          | {:error, reason :: binary, rest :: binary, Lexer.loc()}
  def parse(tag_name, loc, context) do
    module = (context.tags || default_tags())[tag_name]

    if module do
      module.parse(tag_name, loc, context)
    else
      {:error, "Unexpected tag '#{tag_name}'", %{line: loc.line, column: loc.column}}
    end
  end

  @doc """
  Adds a new tag to the tags map.

  It handles both atom and string keys.
  """
  @spec put(map, atom | String.t(), module) :: map
  def put(tags, key, value) when is_atom(key) do
    Map.put(tags, Atom.to_string(key), value)
  end

  def put(tags, key, value) when is_binary(key) do
    Map.put(tags, key, value)
  end

  @doc """
  Removes a tag from the tags map.

  It handles both atom and string keys.
  """
  @spec remove(map, atom | String.t()) :: map
  def remove(tags, key) when is_atom(key) do
    Map.delete(tags, Atom.to_string(key))
  end

  def remove(tags, key) when is_binary(key) do
    Map.delete(tags, key)
  end
end
