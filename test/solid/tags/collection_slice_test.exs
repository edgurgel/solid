defmodule Solid.Tags.CollectionSliceTest do
  use ExUnit.Case, async: true
  alias Solid.Tags.CollectionSlice

  describe "slice/3 without an end (no limit)" do
    test "from 0 returns everything" do
      assert CollectionSlice.slice([1, 2, 3], 0, nil) == [1, 2, 3]
    end

    test "positive from skips items" do
      assert CollectionSlice.slice([1, 2, 3, 4], 2, nil) == [3, 4]
    end

    test "negative from starts at the first item" do
      assert CollectionSlice.slice([1, 2, 3, 4], -2, nil) == [1, 2, 3, 4]
    end

    test "from past the end returns nothing" do
      assert CollectionSlice.slice([1, 2, 3], 5, nil) == []
    end
  end

  describe "slice/3 with an end" do
    test "returns items from `from` up to, not including, `to`" do
      assert CollectionSlice.slice([0, 1, 2, 3, 4, 5], 1, 3) == [1, 2]
    end

    test "to past the end stops at the last item" do
      assert CollectionSlice.slice([1, 2, 3], 1, 10) == [2, 3]
    end

    test "negative from counts the end from the real start" do
      # offset: -2 limit: 3 -> to = 1
      assert CollectionSlice.slice([0, 1, 2, 3], -2, 1) == [0]
    end

    test "to equal to from returns nothing" do
      assert CollectionSlice.slice([1, 2, 3], 1, 1) == []
    end

    test "to before from returns nothing" do
      # offset: 1 limit: -1 -> to = 0
      assert CollectionSlice.slice([0, 1, 2, 3, 4, 5], 1, 0) == []
    end

    test "negative to returns nothing" do
      assert CollectionSlice.slice([1, 2, 3], -5, -1) == []
    end
  end

  describe "slice/3 on other enumerables" do
    test "empty list" do
      assert CollectionSlice.slice([], 0, nil) == []
      assert CollectionSlice.slice([], -1, 2) == []
    end

    test "range" do
      assert CollectionSlice.slice(0..5, 2, nil) == [2, 3, 4, 5]
      assert CollectionSlice.slice(0..5, -2, 2) == [0, 1]
    end

    test "huge range with an end is not materialized" do
      assert CollectionSlice.slice(1..1_000_000_000, 5, 7) == [6, 7]
      assert CollectionSlice.slice(1..1_000_000_000, -5, 2) == [1, 2]
    end

    test "map yields key/value pairs" do
      assert CollectionSlice.slice(%{"a" => 1}, 0, nil) == [{"a", 1}]
      assert CollectionSlice.slice(%{"a" => 1}, 1, nil) == []
    end
  end

  describe "slice/3 on strings" do
    test "a string is returned whole, ignoring from and to" do
      assert CollectionSlice.slice("abc", 0, nil) == ["abc"]
      assert CollectionSlice.slice("abc", 2, nil) == ["abc"]
      assert CollectionSlice.slice("abc", -1, -1) == ["abc"]
      assert CollectionSlice.slice("abc", 1, 0) == ["abc"]
    end
  end
end
