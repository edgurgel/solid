defmodule Solid.FileSystemTest do
  use ExUnit.Case, async: true
  doctest Solid.FileSystem

  alias Solid.BlankFileSystem
  alias Solid.LocalFileSystem

  test "default file system" do
    assert_raise Solid.FileSystem.Error, fn ->
      BlankFileSystem.read_template_file("dummy", nil)
    end
  end

  test "local file system" do
    file_system = LocalFileSystem.new("/some/path")
    assert "/some/path/_mypartial.liquid" == LocalFileSystem.full_path("mypartial", file_system)

    assert "/some/path/dir/_mypartial.liquid" ==
             LocalFileSystem.full_path("dir/mypartial", file_system)

    assert_raise Solid.FileSystem.Error, fn ->
      LocalFileSystem.full_path("../dir/mypartial", file_system)
    end

    assert_raise Solid.FileSystem.Error, fn ->
      LocalFileSystem.full_path("/dir/../../dir/mypartial", file_system)
    end

    assert_raise Solid.FileSystem.Error, fn ->
      LocalFileSystem.full_path("/etc/passwd", file_system)
    end
  end

  def test_custom_template_filename_patterns do
    file_system = LocalFileSystem.new("/some/path", "%s.html")
    assert "/some/path/mypartial.html" == LocalFileSystem.full_path("mypartial", file_system)

    assert "/some/path/dir/mypartial.html" ==
             LocalFileSystem.full_path("dir/mypartial", file_system)
  end
end
