defmodule Solid.Integration.ObjectsTest do
  use ExUnit.Case, async: true
  import Solid.Helpers

  test "no liquid template" do
    assert render("No Number!", %{"key" => 123}) == "No Number!"
  end

  test "single quoted string" do
    assert render("String: {{ 'text' }}") == "String: text"
  end

  test "double quoted string" do
    assert render("String: {{ \"text\" }}") == "String: text"
  end

  test "basic key rendering" do
    assert render("Number {{ key }} ! {{ key }}", %{"key" => 123}) == "Number 123 ! 123"
  end

  test "field with access" do
    assert render("Number {{ key[1] }}", %{"key" => [1, 2, 3]}) == "Number 2"
  end

  test "complex key rendering" do
    hash = %{"key1" => %{"key2" => %{"key3" => 123}}}
    assert render("Number {{ key1.key2.key3 }} !", hash) == "Number 123 !"
  end
end
