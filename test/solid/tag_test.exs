defmodule Solid.TagTest do
  use ExUnit.Case, async: true

  alias Solid.Tag
  alias Solid.Tags

  describe "default_tags/0" do
    test "returns a map with all the default tags" do
      tags = Tag.default_tags()

      assert Map.get(tags, "assign") == Tags.AssignTag
      assert Map.get(tags, "comment") == Tags.CommentTag
    end
  end

  describe "put/3" do
    test "adds a new tag to the map" do
      tags =
        Tag.default_tags()
        |> Tag.put("new_tag", Tags.RawTag)

      assert Map.get(tags, "new_tag") == Tags.RawTag
    end

    test "adds a new tag to the map using an atom as key" do
      tags =
        Tag.default_tags()
        |> Tag.put(:new_tag, Tags.RawTag)

      assert Map.get(tags, "new_tag") == Tags.RawTag
    end
  end

  describe "remove/2" do
    test "removes a tag from the map" do
      tags =
        Tag.default_tags()
        |> Tag.remove("comment")

      refute Map.has_key?(tags, "comment")
    end

    test "removes a tag from the map using an atom as key" do
      tags =
        Tag.default_tags()
        |> Tag.remove(:comment)

      refute Map.has_key?(tags, "comment")
    end
  end
end
