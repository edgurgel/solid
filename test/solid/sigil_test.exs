defmodule Solid.SigilTest do
  use ExUnit.Case, async: true

  import Solid.Sigil

  describe "sigil_LIQUID/2" do
    test "compiles valid templates" do
      template = ~LIQUID"Hello, {{ name }}!"

      assert template == Solid.parse!("Hello, {{ name }}!")
    end

    test "raises CompileError for unclosed tag" do
      code = """
      import Solid.Sigil
      ~LIQUID"Hello, {{ name!"
      """

      assert_raise CompileError, ~r/Liquid template syntax error/, fn ->
        Code.eval_string(code)
      end
    end

    test "raises CompileError for invalid tag" do
      code = """
      import Solid.Sigil
      ~LIQUID"{% invalid_tag %}"
      """

      assert_raise CompileError, ~r/Liquid template syntax error/, fn ->
        Code.eval_string(code)
      end
    end

    test "raises CompileError for unbalanced tags" do
      code = """
      import Solid.Sigil
      ~LIQUID"{% if condition %}No closing endif"
      """

      assert_raise CompileError, ~r/Liquid template syntax error/, fn ->
        Code.eval_string(code)
      end
    end

    test "error message includes line number and contextual information" do
      code = """
      import Solid.Sigil
      ~LIQUID\"\"\"
      Line 1 is fine
      Line 2 has {% invalid_tag %} an error
      Line 3 is also fine
      \"\"\"
      """

      assert_raise CompileError, ~r/Line 2 has {% invalid_tag %} an error/, fn ->
        Code.eval_string(code)
      end
    end

    test "compiles templates with custom tags defined in @liquid_tags" do
      code = """
      defmodule MyModule do
        import Solid.Sigil
        require Solid.Tag

        @liquid_tags Solid.Tag.default_tags() |> Map.put("current_line", CustomTags.CurrentLine)

        def template do
          ~LIQUID"{% current_line %}"
        end
      end
      """

      assert {{:module, my_module, _, _}, _} = Code.eval_string(code)
      assert IO.iodata_to_binary(Solid.render!(my_module.template(), %{})) == "1"
    end
  end
end
