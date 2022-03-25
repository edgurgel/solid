defmodule Solid.Tag.CommentTest do
  use ExUnit.Case, async: true
  alias Solid.Tag.Comment
  alias Solid.Context

  defmodule Parser do
    import NimbleParsec
    defparsec(:parse, Comment.spec(__MODULE__) |> eos())
  end

  test "integration" do
    {:ok, parsed, _, _, _, _} = "{% comment %} a comment {% endcomment %}" |> Parser.parse()

    assert {[], %Context{}} == Comment.render(parsed, %Context{}, [])
  end
end
