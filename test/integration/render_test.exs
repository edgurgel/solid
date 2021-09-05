defmodule Solid.Integration.RenderTest do
  use ExUnit.Case, async: true
  # import Solid.Helpers

  defp render(template, options) do
    "{% render '#{template}' %}"
    |> Solid.parse!()
    |> Solid.render(%{}, options)
    |> to_string()
  end

  defp path(rel) do
    "test/templates/#{rel}"
  end

  defp assert_result(rendered_text, testcase) do
    assert {:ok, content} = File.read(path("#{testcase}/result.txt"))
    assert rendered_text == String.trim(content)
  end

  test "render template in current directory" do
    render("index.liquid", cwd: path("01"))
    |> assert_result("01")
  end

  test "render template withoud extension auto find .solid" do
    render("index", cwd: path("01"))
    |> assert_result("01")
  end

  test "render template not in cwd but in lookup directory" do
    render("index", cwd: path("02/default"), lookup_dir: [path("02/custom")])
    |> assert_result("02")
  end

  test "template exist in many lookup directory but render the first found template" do
    render("index",
      cwd: path("03/default"),
      lookup_dir: [path("03/custom2"), path("03/custom")]
    )
    |> assert_result("03")
  end

  test "template path start with .. only lookup relative to cwd found" do
    render("list",
      cwd: path("04/default/partial"),
      lookup_dir: [path("04/custom/partial")]
    )
    |> assert_result("04")
  end

  test "template path start with .. only lookup relative to cwd not found even exist in lookup directory" do
    render("list",
      cwd: path("05/default/partial"),
      lookup_dir: [path("05/custom/partial")]
    )
    |> assert_result("05")
  end

  test "pass parameters to rendered template" do
    render("index", cwd: path("06"))
    |> assert_result("06")
  end

  test "render template work in loop" do
    render("index", cwd: path("07"))
    |> assert_result("07")
  end
end
