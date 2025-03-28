defmodule Solid.BinaryConditionTest do
  use ExUnit.Case, async: true

  import Solid.BinaryCondition

  describe "eval/2" do
    test "numbers and comparison operators" do
      assert eval({1, :==, 1}) == {:ok, true}
      assert eval({1, :!=, 2}) == {:ok, true}
      assert eval({1, :<>, 2}) == {:ok, true}
      assert eval({1, :<, 2}) == {:ok, true}
      assert eval({2, :>, 1}) == {:ok, true}
      assert eval({1, :>=, 1}) == {:ok, true}
      assert eval({2, :>=, 1}) == {:ok, true}
      assert eval({1, :<=, 2}) == {:ok, true}
      assert eval({1, :<=, 1}) == {:ok, true}
      assert eval({1, :>, -2}) == {:ok, true}
      assert eval({-2, :<, 2}) == {:ok, true}
      assert eval({1.0, :>, -1.0}) == {:ok, true}
      assert eval({-1.0, :<, 1.0}) == {:ok, true}

      assert eval({1, :==, 2}) == {:ok, false}
      assert eval({1, :!=, 1}) == {:ok, false}
      assert eval({1, :<>, 1}) == {:ok, false}
      assert eval({1, :<, 0}) == {:ok, false}
      assert eval({2, :>, 4}) == {:ok, false}
      assert eval({1, :>=, 3}) == {:ok, false}
      assert eval({2, :>=, 4}) == {:ok, false}
      assert eval({1, :<=, 0}) == {:ok, false}
    end

    test "contains" do
      assert eval({"jose", :contains, "o"}) == {:ok, true}
      assert eval({"jose", :contains, "jose"}) == {:ok, true}

      assert eval({"jose", :contains, "john"}) == {:ok, false}
    end

    test "number and string" do
      assert eval({1, :<, "jose"}) == {:error, "comparison of Integer with String failed"}
      assert eval({"jose", :<, 1}) == {:error, "comparison of String with 1 failed"}

      assert eval({1, :==, "jose"}) == {:ok, false}

      assert eval({1.0, :<, "jose"}) == {:error, "comparison of Float with String failed"}
      assert eval({"jose", :<, 1.0}) == {:ok, false}
      assert eval({1.0, :==, "jose"}) == {:ok, false}
    end
  end
end
