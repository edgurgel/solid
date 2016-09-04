defmodule SolidTest do
  use ExUnit.Case
  doctest Solid

  defp parse(text, hash \\ %{}) do
    Solid.parse(text) |> Solid.render(hash) |> to_string
  end

  test "no liquid template" do
    assert parse("No Number!", %{ "key" => 123 }) == "No Number!"
  end

  test "basic key rendering" do
    assert parse("Number {{ key }} !", %{ "key" => 123 }) == "Number 123 !"
  end

  test "complex key rendering" do
    hash = %{ "key1" => %{ "key2" => %{ "key3" => 123 }}}
    assert parse("Number {{ key1.key2.key3 }} !", hash) == "Number 123 !"
  end

  test "upcase filter" do
    assert parse("Text {{ key | upcase }} !", %{ "key" => "abc" }) == "Text ABC !"
  end

  test "multiple filters" do
    assert parse("Text {{ key | default: 1 | upcase }} !", %{ "key" => "abc" }) == "Text ABC !"
  end

  test "default filter with default integer" do
    assert parse("Number {{ key | default: 456 }} !") == "Number 456 !"
  end

  test "default filter with default string" do
    assert parse("Number {{ key | default: \"456\" }} !", %{}) == "Number 456 !"
  end

  test "default filter with default float" do
    assert parse("Number {{ key | default: 44.5 }} !", %{}) == "Number 44.5 !"
  end

  test "default filter with nil" do
    assert parse("Number {{ nil | default: 456 }} !", %{ "nil" => 123 }) == "Number 456 !"
  end

  test "default filter with an integer" do
    assert parse("Number {{ 123 | default: 456 }} !", %{}) == "Number 123 !"
  end

  test "replace" do
    assert parse("{{ \"Take my protein pills and put my helmet on\" | replace: \"my\", \"your\" }}", %{}) == "Take your protein pills and put your helmet on"
  end
end
