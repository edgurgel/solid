defmodule Solid.Integration.TagsTest do
  use ExUnit.Case, async: true
  import Solid.Helpers

  # test "open tag" do
    # assert render("{% Text", %{ "key" => 123 }) == "{% Text"
  # end

  test "if true expression" do
    assert render("{% if 1 == 1 %}True{% endif %} is True", %{ "key" => 123 }) == "True is True"
  end

  test "if false expression" do
    assert render("{% if 1 != 1 %}True{% endif %}False?", %{ "key" => 123 }) == "False?"
  end

  test "if true" do
    assert render("{% if true %}True{% endif %} is True", %{ "key" => 123 }) == "True is True"
  end

  test "if false" do
    assert render("{% if false %}True{% endif %}False?", %{ "key" => 123 }) == "False?"
  end

  test "nested if" do
    assert render("{% if 1 == 1 %}{% if 1 != 2 %}True{% endif %}{% endif %} is True", %{ "key" => 123 }) == "True is True"
  end

  test "if with object" do
    assert render("{% if 1 != 2 %}{{ key }}{% endif %}", %{ "key" => 123 }) == "123"
  end
end
