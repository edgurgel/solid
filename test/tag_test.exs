defmodule Solid.TagTest do
  use ExUnit.Case
  import Solid.Tag
  doctest Solid.Tag

  @true_exp  [{{:value, 1}, :==, {:value, 1}}]
  @false_exp [{{:value, 1}, :!=, {:value, 1}}]

  describe "Tag.eval/2" do
    test "eval if_exp true" do
      exp = %{expression: @true_exp, text: "if"}
      assert eval([{:if_exp, exp}], %{}) == "if"
    end

    test "eval if_exp false" do
      exp = %{expression: @false_exp, text: "if"}
      assert eval([{:if_exp, exp}], %{}) == nil
    end

    test "eval if_exp true else" do
      exp = %{expression: @true_exp, text: "if"}
      else_exp = %{text: "else"}
      assert eval([{:if_exp, exp},
                   {:else_exp, else_exp}], %{}) == "if"
    end

    test "eval if_exp false else" do
      exp = %{expression: @false_exp, text: "if"}
      else_exp = %{text: "else"}
      assert eval([{:if_exp, exp},
                   {:else_exp, else_exp}], %{}) == "else"
    end

    test "eval if_exp false elsif true" do
      exp = %{expression: @false_exp, text: "if"}
      elsif_exp = %{expression: @true_exp, text: "elsif"}
      assert eval([{:if_exp, exp},
                   {:elsif_exps, [{:elsif_exp, elsif_exp}]}], %{}) == "elsif"
    end

    test "eval if_exp false elsif false" do
      exp = %{expression: @false_exp, text: "if"}
      elsif_exp = %{expression: @false_exp, text: "elsif"}
      assert eval([{:if_exp, exp},
                   {:elsif_exps, [{:elsif_exp, elsif_exp}]}], %{}) == nil
    end

    test "eval if_exp false elsif false else" do
      exp = %{expression: @false_exp, text: "if"}
      elsif_exp = %{expression: @false_exp, text: "elsif"}
      else_exp = %{text: "else"}
      assert eval([{:if_exp, exp},
                   {:elsif_exps, [{:elsif_exp, elsif_exp}]},
                   {:else_exp, else_exp}], %{}) == "else"
    end

    test "eval unless_exp true" do
      exp = %{expression: @false_exp, text: "unless"}
      assert eval([{:unless_exp, exp}], %{}) == "unless"
    end

    test "eval unless_exp false" do
      exp = %{ expression: @true_exp, text: "unless" }
      assert eval([{:unless_exp, exp}], %{}) == nil
    end

    test "eval unless_exp true else" do
      exp = %{expression: @true_exp, text: "unless"}
      else_exp = %{text: "else"}
      assert eval([{:unless_exp, exp},
                   {:else_exp, else_exp}], %{}) == "else"
    end

    test "eval unless_exp false else" do
      exp = %{expression: @false_exp, text: "unless"}
      else_exp = %{text: "else"}
      assert eval([{:unless_exp, exp},
                   {:else_exp, else_exp}], %{}) == "unless"
    end

    test "eval unless_exp true elsif true" do
      exp = %{expression: @true_exp, text: "unless"}
      elsif_exp = %{expression: @true_exp, text: "elsif"}
      assert eval([{:unless_exp, exp},
                   {:elsif_exps, [{:elsif_exp, elsif_exp}]}], %{}) == "elsif"
    end

    test "eval unless_exp false elsif false" do
      exp = %{expression: @true_exp, text: "unless"}
      elsif_exp = %{expression: @false_exp, text: "elsif"}
      assert eval([{:unless_exp, exp},
                   {:elsif_exps, [{:elsif_exp, elsif_exp}]}], %{}) == nil
    end

    test "eval unless_exp false elsif false else" do
      exp = %{expression: @true_exp, text: "unless"}
      elsif_exp = %{expression: @false_exp, text: "elsif"}
      else_exp = %{text: "else"}
      assert eval([{:unless_exp, exp},
                   {:elsif_exps, [{:elsif_exp, elsif_exp}]},
                   {:else_exp, else_exp}], %{}) == "else"
    end
  end
end
