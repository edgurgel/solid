defmodule Solid.ToRubyTest do
  use ExUnit.Case, async: true

  alias Solid.ToRuby

  test "converts a map to a ruby-like hash string" do
    map = %{"title" => "Title 1", "author" => "John Doe"}
    expected = "{\"author\"=>\"John Doe\", \"title\"=>\"Title 1\"}"
    assert ToRuby.hash(map) == expected
  end

  test "converts a map with numbers" do
    map = %{"integer" => 123, "float" => 45.6}
    expected = "{\"float\"=>45.6, \"integer\"=>123}"
    assert ToRuby.hash(map) == expected
  end

  test "converts a nested map" do
    map = %{"a" => 1, "b" => %{"c" => 2}}
    expected = "{\"a\"=>1, \"b\"=>{\"c\"=>2}}"
    assert ToRuby.hash(map) == expected
  end

  test "converts a map with various data types" do
    map = %{
      "nil_value" => nil,
      "bool_true" => true,
      "bool_false" => false,
      "atom_value" => :my_atom,
      "list_value" => [1, "two", :three]
    }

    expected =
      "{\"atom_value\"=>:my_atom, \"bool_false\"=>false, \"bool_true\"=>true, \"list_value\"=>[1, \"two\", :three], \"nil_value\"=>nil}"

    assert ToRuby.hash(map) == expected
  end
end
