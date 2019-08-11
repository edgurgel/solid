defmodule Solid.TagTest do
  use ExUnit.Case
  import Solid.Tag
  alias Solid.Context
  doctest Solid.Tag

  @true_exp  [{{:value, 1}, :==, {:value, 1}}]
  @false_exp [{{:value, 1}, :!=, {:value, 1}}]

  describe "Tag.eval/2" do
    test "eval comment" do
      assert eval(:comment, %Context{}) == {nil, %Context{}}
    end

    test "eval case_exp matching" do
      context = %Context{ vars: %{ "x" => "1"}}
      assert eval([{:case_exp, [{:field, ["x"]}]},
                   {:whens, %{ "1" => %{text: "one"} }}], context) == {"one", context}
    end

    test "eval case_exp not matching" do
      context = %Context{ vars: %{"x" => "1"}}
      assert eval([{:case_exp, [{:field, ["x"]}]},
                   {:whens, %{ "2" => %{text: "two"} }}], context) == {nil, context}
    end

    test "eval case_exp not matching having else_exp" do
      context = %Context{ vars: %{ "x" => "1"}}
      else_exp = %{text: "else"}
      assert eval([{:case_exp, [{:field, ["x"]}]},
                   {:whens, %{ "2" => %{text: "two"} }},
                   {:else_exp, else_exp}], context) == {"else", context}
    end

    test "eval if_exp true" do
      context = %Context{}
      exp = %{expression: @true_exp, text: "if"}
      assert eval([{:if_exp, exp}], %Context{}) == {"if", context}
    end

    test "eval if_exp false" do
      context = %Context{}
      exp = %{expression: @false_exp, text: "if"}
      assert eval([{:if_exp, exp}], context) == {nil, context}
    end

    test "eval if_exp true else" do
      context = %Context{}
      exp = %{expression: @true_exp, text: "if"}
      else_exp = %{text: "else"}
      assert eval([{:if_exp, exp},
                   {:else_exp, else_exp}], context) == {"if", context}
    end

    test "eval if_exp false else" do
      context = %Context{}
      exp = %{expression: @false_exp, text: "if"}
      else_exp = %{text: "else"}
      assert eval([{:if_exp, exp},
                   {:else_exp, else_exp}], context) == {"else", context}
    end

    test "eval if_exp false elsif true" do
      context = %Context{}
      exp = %{expression: @false_exp, text: "if"}
      elsif_exp = %{expression: @true_exp, text: "elsif"}
      assert eval([{:if_exp, exp},
                   {:elsif_exps, [{:elsif_exp, elsif_exp}]}], context) == {"elsif", context}
    end

    test "eval if_exp false elsif false" do
      context = %Context{}
      exp = %{expression: @false_exp, text: "if"}
      elsif_exp = %{expression: @false_exp, text: "elsif"}
      assert eval([{:if_exp, exp},
                   {:elsif_exps, [{:elsif_exp, elsif_exp}]}], context) == {nil, context}
    end

    test "eval if_exp false elsif false else" do
      context = %Context{}
      exp = %{expression: @false_exp, text: "if"}
      elsif_exp = %{expression: @false_exp, text: "elsif"}
      else_exp = %{text: "else"}
      assert eval([{:if_exp, exp},
                   {:elsif_exps, [{:elsif_exp, elsif_exp}]},
                   {:else_exp, else_exp}], context) == {"else", context}
    end

    test "eval unless_exp true" do
      context = %Context{}
      exp = %{expression: @false_exp, text: "unless"}
      assert eval([{:unless_exp, exp}], context) == {"unless", context}
    end

    test "eval unless_exp false" do
      context = %Context{}
      exp = %{ expression: @true_exp, text: "unless" }
      assert eval([{:unless_exp, exp}], context) == {nil, context}
    end

    test "eval unless_exp true else" do
      context = %Context{}
      exp = %{expression: @true_exp, text: "unless"}
      else_exp = %{text: "else"}
      assert eval([{:unless_exp, exp},
                   {:else_exp, else_exp}], context) == {"else", context}
    end

    test "eval unless_exp false else" do
      context = %Context{}
      exp = %{expression: @false_exp, text: "unless"}
      else_exp = %{text: "else"}
      assert eval([{:unless_exp, exp},
                   {:else_exp, else_exp}], context) == {"unless", context}
    end

    test "eval unless_exp true elsif true" do
      context = %Context{}
      exp = %{expression: @true_exp, text: "unless"}
      elsif_exp = %{expression: @true_exp, text: "elsif"}
      assert eval([{:unless_exp, exp},
                   {:elsif_exps, [{:elsif_exp, elsif_exp}]}], context) == {"elsif", context}
    end

    test "eval unless_exp false elsif false" do
      context = %Context{}
      exp = %{expression: @true_exp, text: "unless"}
      elsif_exp = %{expression: @false_exp, text: "elsif"}
      assert eval([{:unless_exp, exp},
                   {:elsif_exps, [{:elsif_exp, elsif_exp}]}], context) == {nil, context}
    end

    test "eval unless_exp false elsif false else" do
      context = %Context{}
      exp = %{expression: @true_exp, text: "unless"}
      elsif_exp = %{expression: @false_exp, text: "elsif"}
      else_exp = %{text: "else"}
      assert eval([{:unless_exp, exp},
                   {:elsif_exps, [{:elsif_exp, elsif_exp}]},
                   {:else_exp, else_exp}], context) == {"else", context}
    end

    test "eval assign_exp with literal value" do
      context = %Context{ vars: %{ "x" => "1"}}
      new_context = %Context{ vars: %{ "x" => "1", "y" => "abc"}}
      assert eval({:assign_exp, {:field, ["y"]}, {:value, "abc"}}, context) == {nil, new_context}
    end

    test "eval assign_exp with field" do
      context = %Context{ vars: %{ "x" => %{ "y" => "abc"}}}
      new_context = %Context{ vars: %{ "x" => %{ "y" => "abc"}, "z" => "abc"}}
      assert eval({:assign_exp, {:field, ["z"]}, {:field, ["x", "y"]}}, context) == {nil, new_context}
    end

    test "eval increment_exp with previous value" do
      context = %Context{counter_vars: %{ "x" => 1}}
      new_context = %Context{counter_vars: %{"x" => 2}}
      assert eval({:increment_exp, {:field, ["x"]}}, context) == {[{:string, "1"}, []], new_context}
    end

    test "eval increment_exp with no previous value" do
      context = %Context{ counter_vars: %{ "x" => "1"}}
      new_context = %Context{ counter_vars: %{ "x" => "1", "y" => 1}}
      assert eval({:increment_exp, {:field, ["y"]}}, context) == {[{:string, "0"}, []], new_context}
    end
  end
end
