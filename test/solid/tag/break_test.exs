defmodule Solid.Tag.BreakTest do
  use ExUnit.Case, async: true
  alias Solid.Tag.Break
  alias Solid.Context

  defmodule Parser do
    import NimbleParsec
    defparsec(:parse, Break.spec(__MODULE__) |> eos())
  end

  test "integration" do
    {:ok, parsed, _, _, _, _} = "{% break %}" |> Parser.parse()

    assert catch_throw(Break.render(parsed, %Context{}, [])) ==
             {:break_exp, [], %Solid.Context{}}
  end
end
