defmodule Solid.Integration.LinesTest do
  use ExUnit.Case, async: true

  @tags Solid.Tag.default_tags()
        |> Map.put("current_line", CustomTags.CurrentLine)

  defp render(template) do
    template
    |> Solid.parse!(tags: @tags)
    |> Solid.render!(%{})
    |> IO.iodata_to_binary()
  end

  describe "line number processing" do
    test "text" do
      template = """
      text
      {% current_line %}
      text
      """

      assert render(template) ==
               """
               text
               2
               text
               """
    end

    test "comment" do
      template = """
      {% comment %} {% assign x = 1 %} {% endcomment -%}
      {% current_line %}
      """

      assert render(template) ==
               """
               2
               """
    end

    test "raw" do
      template = """
      {% raw %}{% assign x = 1 %}{% endraw %}
      {% current_line %}
      """

      assert render(template) ==
               """
               {% assign x = 1 %}
               2
               """
    end
  end
end
