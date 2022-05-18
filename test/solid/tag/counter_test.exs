defmodule Solid.Tag.CounterTest do
  use ExUnit.Case, async: true
  alias Solid.Tag.Counter
  alias Solid.Context

  defmodule Parser do
    import NimbleParsec
    defparsec(:parse, Counter.spec(__MODULE__) |> eos())
  end

  test "integration" do
    {:ok, parsed, _, _, _, _} = "{% increment my_number %}" |> Parser.parse()

    assert {[text: "4"], context} =
             Counter.render(parsed, %Context{counter_vars: %{"my_number" => 4}}, [])

    assert context.counter_vars == %{"my_number" => 5}
  end
end
