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
  end
end
