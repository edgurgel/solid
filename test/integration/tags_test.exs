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

  test "else true" do
    assert render("{% if 1 == 1 %}True{% else %}False{% endif %} is True", %{ "key" => 123 }) == "True is True"
  end

  test "else false" do
    assert render("{% if 1 != 1 %}True{% else %}False{% endif %} is False", %{ "key" => 123 }) == "False is False"
  end

  test "if elsif" do
    assert render("{% if 1 != 1 %}if{% elsif 1 == 1 %}elsif{% endif %}") == "elsif"
  end

  test "unless true expression" do
    assert render("{% unless 1 == 1 %}True{% endunless %}False?", %{ "key" => 123 }) == "False?"
  end

  test "unless false expression" do
    assert render("{% unless 1 != 1 %}True{% endunless %} is True", %{ "key" => 123 }) == "True is True"
  end

  test "unless true" do
    assert render("{% unless true %}False{% endunless %}False?", %{ "key" => 123 }) == "False?"
  end

  test "unless false" do
    assert render("{% unless false %}True{% endunless %} is True", %{ "key" => 123 }) == "True is True"
  end

  test "nested unless" do
    assert render("{% unless 1 != 1 %}{% unless 1 == 2 %}True{% endunless %}{% endunless %} is True", %{ "key" => 123 }) == "True is True"
  end

  test "unless with object" do
    assert render("{% unless 1 == 2 %}{{ key }}{% endunless %}", %{ "key" => 123 }) == "123"
  end

  test "unless elsif" do
    assert render("{% unless 1 == 1 %}unless{% elsif 1 == 1 %}elsif{% endunless %}") == "elsif"
  end
end
