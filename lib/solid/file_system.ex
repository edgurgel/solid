defmodule Solid.FileSystem do
  @moduledoc """
  A file system is a way to let your templates retrieve other templates for use with the include tag.

  You can implement a module that retrieve templates from the database, from the file system using a different path structure, you can provide them as hard-coded inline strings, or any manner that you see fit.

  You can add additional instance variables, arguments, or methods as needed.

  Example:

  ```elixir
  file_system = Solid.LocalFileSystem.new(template_path)
  text = Solid.render(template, file_system: {Solid.LocalFileSystem, file_system})
  ```

  This will render the template with a LocalFileSystem implementation rooted at 'template_path'.
  """

  # Called by Solid to retrieve a template file
  @callback read_template_file(binary(), options :: any()) ::
              {:ok, String.t()} | {:error, Exception.t()}

  defmodule Error do
    @type t :: %__MODULE__{}
    defexception [:reason, :loc]

    def message(reason), do: reason
  end
end

defmodule Solid.BlankFileSystem do
  @moduledoc """
  Default file system that return error on call
  """
  @behaviour Solid.FileSystem

  @impl true
  def read_template_file(_template_path, _opts) do
    {:error, %Solid.FileSystem.Error{reason: "This solid context does not allow includes."}}
  end
end

defmodule Solid.LocalFileSystem do
  @moduledoc """
  This implements an abstract file system which retrieves template files named in a manner similar to Liquid.
  ie. with the template name prefixed with an underscore. The extension ".liquid" is also added.

  For security reasons, template paths are only allowed to contain letters, numbers, and underscore.

  **Example:**

      file_system = Solid.LocalFileSystem.new("/some/path")

      Solid.LocalFileSystem.full_path(file_system, "mypartial")
      # => "/some/path/_mypartial.liquid"

      Solid.LocalFileSystem.full_path(file_system,"dir/mypartial")
      # => "/some/path/dir/_mypartial.liquid"

  Optionally in the second argument you can specify a custom pattern for template filenames.
  `%s` will be replaced with template basename
  Default pattern is "_%s.liquid".

  **Example:**

      file_system = Solid.LocalFileSystem.new("/some/path", "%s.html")

      Solid.LocalFileSystem.full_path( "index", file_system)
      # => "/some/path/index.html"

  """
  defstruct [:root, :pattern]
  @behaviour Solid.FileSystem

  def new(root, pattern \\ "_%s.liquid") do
    %__MODULE__{
      root: root,
      pattern: pattern
    }
  end

  @impl true
  def read_template_file(template_path, file_system) do
    with {:ok, full_path} <- full_path(template_path, file_system) do
      if File.exists?(full_path) do
        {:ok, File.read!(full_path)}
      else
        {:error, %Solid.FileSystem.Error{reason: "No such template '#{template_path}'"}}
      end
    end
  end

  defp full_path(template_path, file_system) do
    if String.match?(template_path, Regex.compile!("^[^./][a-zA-Z0-9_/-]+$")) do
      template_name = String.replace(file_system.pattern, "%s", Path.basename(template_path))

      full_path =
        if String.contains?(template_path, "/") do
          file_system.root
          |> Path.join(Path.dirname(template_path))
          |> Path.join(template_name)
          |> Path.expand()
        else
          file_system.root
          |> Path.join(template_name)
          |> Path.expand()
        end

      if String.starts_with?(full_path, Path.expand(file_system.root)) do
        {:ok, full_path}
      else
        {:error,
         %Solid.FileSystem.Error{reason: "Illegal template path '#{Path.expand(full_path)}'"}}
      end
    else
      {:error, %Solid.FileSystem.Error{reason: "Illegal template name '#{template_path}'"}}
    end
  end
end
