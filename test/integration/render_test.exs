defmodule Solid.Integration.RenderTest do
  use ExUnit.Case, async: true
  # import Solid.Helpers

  def render(template, options) do
    Solid.parse!(template)
    |> Solid.render(%{}, options)
  end

  def path(rel) do
    "test/templates/#{rel}"
  end

  test "render template in current directory" do
    assert "" = render("{% render 'index.liquid' %}", cwd: path("01"))
  end

  test "render template withoud extension auto find .solid" do
  end

  test "render template not in cwd but in lookup directory" do
  end

  test "template exist in many lookup directory but render the first found template" do
  end

  test "template path start with .. only lookup relative to cwd found" do
  end

  test "template path start with .. only lookup relative to cwd not found even exist in lookup directory" do
  end

  test "pass parameters to rendered template" do
  end
end
