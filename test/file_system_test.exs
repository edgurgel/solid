defmodule Solid.FileSystemTest do
  use ExUnit.Case, async: true
  doctest Solid.FileSystem

  alias Solid.BlankFileSystem
  alias Solid.LocalFileSystem

  test "default file system" do
    assert_raise File.Error, fn ->
      BlankFileSystem.read_template_file(nil, "dummy")
    end
  end

  test "local file system" do
    file_system = LocalFileSystem.new("/some/path")
    assert "/some/path/_mypartial.liquid" == LocalFileSystem.full_path(file_system, "mypartial")

    assert "/some/path/dir/_mypartial.liquid" ==
             LocalFileSystem.full_path(file_system, "dir/mypartial")

    assert_raise File.Error, fn ->
      LocalFileSystem.full_path(file_system, "../dir/mypartial")
    end

    assert_raise File.Error, fn ->
      LocalFileSystem.full_path(file_system, "/dir/../../dir/mypartial")
    end

    assert_raise File.Error, fn ->
      LocalFileSystem.full_path(file_system, "/etc/passwd")
    end
  end

  def test_custom_template_filename_patterns do
    file_system = LocalFileSystem.new("/some/path", "%s.html")
    assert "/some/path/mypartial.html" == LocalFileSystem.full_path(file_system, "mypartial")

    assert "/some/path/dir/mypartial.html" ==
             LocalFileSystem.full_path(file_system, "dir/mypartial")
  end
end
