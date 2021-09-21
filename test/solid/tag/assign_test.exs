defmodule Solid.Tag.AssignTest do
  use ExUnit.Case, async: true
  alias Solid.Tag.Assign
  alias Solid.Context

  defmodule Parser do
    import NimbleParsec
    defparsec(:parse, Assign.spec(__MODULE__) |> eos())
  end

  test "integration" do
    {:ok, parsed, _, _, _, _} = "{% assign first = 3 %}" |> Parser.parse()

    assert {[], context} = Assign.render(parsed, %Context{}, [])

    assert context.vars == %{"first" => 3}
  end
end
