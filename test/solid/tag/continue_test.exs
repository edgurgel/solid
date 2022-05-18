defmodule Solid.Tag.ContinueTest do
  use ExUnit.Case, async: true
  alias Solid.Tag.Continue
  alias Solid.Context

  defmodule Parser do
    import NimbleParsec
    defparsec(:parse, Continue.spec(__MODULE__) |> eos())
  end

  test "integration" do
    {:ok, parsed, _, _, _, _} = "{% continue %}" |> Parser.parse()

    assert catch_throw(Continue.render(parsed, %Context{}, [])) ==
             {:continue_exp, [], %Solid.Context{}}
  end
end
