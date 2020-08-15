defmodule Solid.TagTest do
  use ExUnit.Case
  import Solid.Tag
  alias Solid.Context
  doctest Solid.Tag

  @true_exp [[arg1: [value: 1], op: [:==], arg2: [value: 1]]]
  @false_exp [[arg1: [value: 1], op: [:!=], arg2: [value: 1]]]

  describe "Tag.eval/2" do
    test "eval case_exp matching" do
      context = %Context{vars: %{"x" => "1"}}

      assert eval(
               [case_exp: [field: ["x"]], whens: %{"1" => "one"}],
               context,
               []
             ) == {"one", context}
    end

    test "eval case_exp not matching" do
      context = %Context{vars: %{"x" => "1"}}

      assert eval(
               [case_exp: [field: ["x"]], whens: %{"2" => "two"}],
               context,
               []
             ) == {nil, context}
    end

    test "eval case_exp not matching having else_exp" do
      context = %Context{vars: %{"x" => "1"}}
      else_exp = [result: "else"]

      assert eval(
               [
                 case_exp: [field: ["x"]],
                 whens: %{"2" => "two"},
                 else_exp: else_exp
               ],
               context,
               []
             ) == {"else", context}
    end

    test "eval if_exp true" do
      context = %Context{}
      exp = [expression: @true_exp, result: "if"]
      assert eval([{:if_exp, exp}], %Context{}, []) == {"if", context}
    end

    test "eval if_exp false" do
      context = %Context{}
      exp = [expression: @false_exp, result: "if"]
      assert eval([{:if_exp, exp}], context, []) == {nil, context}
    end

    test "eval if_exp true else" do
      context = %Context{}
      exp = [expression: @true_exp, result: "if"]
      else_exp = %{result: "else"}

      assert eval(
               [{:if_exp, exp}, {:else_exp, else_exp}],
               context,
               []
             ) == {"if", context}
    end

    test "eval if_exp false else" do
      context = %Context{}
      exp = [expression: @false_exp, result: "if"]
      else_exp = [result: "else"]

      assert eval(
               [{:if_exp, exp}, {:else_exp, else_exp}],
               context,
               []
             ) == {"else", context}
    end

    test "eval if_exp false elsif true" do
      context = %Context{}
      exp = [expression: @false_exp, result: "if"]
      elsif_exp = [expression: @true_exp, result: "elsif"]

      assert eval(
               [{:if_exp, exp}, {:elsif_exps, [{:elsif_exp, elsif_exp}]}],
               context,
               []
             ) == {"elsif", context}
    end

    test "eval if_exp false elsif false" do
      context = %Context{}
      exp = [expression: @false_exp, result: "if"]
      elsif_exp = [expression: @false_exp, result: "elsif"]

      assert eval(
               [{:if_exp, exp}, {:elsif_exps, [{:elsif_exp, elsif_exp}]}],
               context,
               []
             ) == {nil, context}
    end

    test "eval if_exp false elsif false else" do
      context = %Context{}
      exp = [expression: @false_exp, result: "if"]
      elsif_exp = [expression: @false_exp, result: "elsif"]
      else_exp = %{result: "else"}

      assert eval(
               [{:if_exp, exp}, {:elsif_exps, [{:elsif_exp, elsif_exp}]}, {:else_exp, else_exp}],
               context,
               []
             ) == {"else", context}
    end

    test "eval unless_exp true" do
      context = %Context{}
      exp = [expression: @false_exp, result: "unless"]
      assert eval([{:unless_exp, exp}], context, []) == {"unless", context}
    end

    test "eval unless_exp false" do
      context = %Context{}
      exp = %{expression: @true_exp, result: "unless"}
      assert eval([{:unless_exp, exp}], context, []) == {nil, context}
    end

    test "eval unless_exp true else" do
      context = %Context{}
      exp = [expression: @true_exp, result: "unless"]
      else_exp = %{result: "else"}

      assert eval(
               [{:unless_exp, exp}, {:else_exp, else_exp}],
               context,
               []
             ) == {"else", context}
    end

    test "eval unless_exp false else" do
      context = %Context{}
      exp = [expression: @false_exp, result: "unless"]
      else_exp = %{result: "else"}

      assert eval(
               [{:unless_exp, exp}, {:else_exp, else_exp}],
               context,
               []
             ) == {"unless", context}
    end

    test "eval unless_exp true elsif true" do
      context = %Context{}
      exp = [expression: @true_exp, result: "unless"]
      elsif_exp = [expression: @true_exp, result: "elsif"]

      assert eval(
               [{:unless_exp, exp}, {:elsif_exps, [{:elsif_exp, elsif_exp}]}],
               context,
               []
             ) == {"elsif", context}
    end

    test "eval unless_exp false elsif false" do
      context = %Context{}
      exp = [expression: @true_exp, result: "unless"]
      elsif_exp = [expression: @false_exp, result: "elsif"]

      assert eval(
               [{:unless_exp, exp}, {:elsif_exps, [{:elsif_exp, elsif_exp}]}],
               context,
               []
             ) == {nil, context}
    end

    test "eval unless_exp false elsif false else" do
      context = %Context{}
      exp = [expression: @true_exp, result: "unless"]
      elsif_exp = [expression: @false_exp, result: "elsif"]
      else_exp = %{result: "else"}

      assert eval(
               [
                 {:unless_exp, exp},
                 {:elsif_exps, [{:elsif_exp, elsif_exp}]},
                 {:else_exp, else_exp}
               ],
               context,
               []
             ) == {"else", context}
    end

    test "eval assign_exp with literal value" do
      context = %Context{vars: %{"x" => "1"}}
      new_context = %Context{vars: %{"x" => "1", "y" => "abc"}}

      assert eval(
               [
                 assign_exp: [
                   field: ["y"],
                   argument: [value: "abc"],
                   filters: []
                 ]
               ],
               context,
               []
             ) ==
               {nil, new_context}
    end

    test "eval assign_exp with literal value and filters" do
      context = %Context{vars: %{"x" => "1"}}
      new_context = %Context{vars: %{"x" => "1", "y" => "ABC"}}

      assert eval(
               [
                 assign_exp: [
                   field: ["y"],
                   argument: [value: "abc"],
                   filters: [filter: ["upcase", {:arguments, []}]]
                 ]
               ],
               context,
               []
             ) ==
               {nil, new_context}
    end

    test "eval assign_exp with field" do
      context = %Context{vars: %{"x" => %{"y" => "abc"}}}
      new_context = %Context{vars: %{"x" => %{"y" => "abc"}, "z" => "abc"}}

      assert eval(
               [
                 assign_exp: [
                   field: ["z"],
                   argument: [field: ["x", "y"]],
                   filters: []
                 ]
               ],
               context,
               []
             ) == {nil, new_context}
    end

    test "eval assign_exp with field and filters" do
      context = %Context{vars: %{"x" => %{"y" => "abc"}}}
      new_context = %Context{vars: %{"x" => %{"y" => "abc"}, "z" => "ABC"}}

      assert eval(
               [
                 assign_exp: [
                   field: ["z"],
                   argument: [field: ["x", "y"]],
                   filters: [filter: ["upcase", {:arguments, []}]]
                 ]
               ],
               context,
               []
             ) == {nil, new_context}
    end

    test "eval increment with previous value" do
      context = %Context{counter_vars: %{"x" => 1}}
      new_context = %Context{counter_vars: %{"x" => 2}}

      assert eval([counter_exp: [{1, 0}, {:field, ["x"]}]], context, []) ==
               {[text: "1"], new_context}
    end

    test "eval increment with no previous value" do
      context = %Context{counter_vars: %{"x" => "1"}}
      new_context = %Context{counter_vars: %{"x" => "1", "y" => 1}}

      assert eval([counter_exp: [{1, 0}, {:field, ["y"]}]], context, []) ==
               {[text: "0"], new_context}
    end

    test "eval decrement with previous value" do
      context = %Context{counter_vars: %{"x" => 1}}
      new_context = %Context{counter_vars: %{"x" => 0}}

      assert eval([counter_exp: [{-1, -1}, {:field, ["x"]}]], context, []) ==
               {[text: "1"], new_context}
    end

    test "eval decrement with no previous value" do
      context = %Context{counter_vars: %{"x" => "1"}}
      new_context = %Context{counter_vars: %{"x" => "1", "y" => -2}}

      assert eval([counter_exp: [{-1, -1}, {:field, ["y"]}]], context, []) ==
               {[text: "-1"], new_context}
    end

    test "eval custom tag invocation" do
      context = %Context{}
      exp = [expression: @true_exp, result: "if"]
      assert eval([{:if_exp, exp}], %Context{}, []) == {"if", context}
    end
  end
end
