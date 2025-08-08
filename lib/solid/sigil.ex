defmodule Solid.Sigil do
  @moduledoc """
  Provides the `~LIQUID` sigil for validating and compiling Liquid templates using Solid.

  This sigil validates the template at compile time and returns a compiled Solid template.
  If the template has syntax errors, it will raise a CompileError with detailed information.

  ## Examples

      iex> import Solid.Sigil
      iex> template = ~LIQUID\"\"\"
      ...> Hello, {{ name }}!
      ...> \"\"\"
      iex> Solid.render(template, %{"name" => "World"})
      {:ok, "Hello, World!"}

  An optional module attribute @liquid_tags can set which tags will be used while parsing.

      defmodule MyModule do
        import Solid.Sigil

        @liquid_tags Solid.Tag.default_tags() |> Map.put("current_line", CustomTags.CurrentLine)

        def template do
          ~LIQUID"{% current_line %}"
        end
      end
  """

  # Custom sigil for validating and compiling Liquid templates using Solid
  defmacro sigil_LIQUID({:<<>>, _meta, [string]}, _modifiers) do
    line = __CALLER__.line
    file = __CALLER__.file

    tags =
      if __CALLER__.module do
        Module.get_attribute(__CALLER__.module, :liquid_tags)
      end

    opts = if tags, do: [tags: tags], else: []

    try do
      # Validate the template during compile time
      parsed_template = Solid.parse!(string, opts)

      # Return the parsed template
      Macro.escape(parsed_template)
    rescue
      e in Solid.TemplateError ->
        # Grab just the first error
        error = hd(e.errors)
        # Extract template line number (first element of the tuple)
        template_line = error.meta.line
        # Calculate actual line number in the file
        actual_line = line + template_line

        # Extract just the problematic portion of the template
        template_lines = String.split(string, "\n")
        context_start = max(0, template_line - 2)
        context_end = min(length(template_lines), template_line + 2)

        context_lines =
          template_lines
          |> Enum.slice(context_start, context_end - context_start)
          |> Enum.with_index(line + context_start + 1)
          |> Enum.map_join("\n", fn {line_text, idx} ->
            indicator = if idx == actual_line, do: "→ ", else: "  "
            "#{indicator}#{idx}: #{line_text}"
          end)

        # Prepare a more helpful error message
        message = """
        Liquid template syntax error at line #{actual_line}:

        #{context_lines}

        Error: #{error.reason}
        """

        # Re-raise with better context
        reraise %CompileError{
                  file: file,
                  line: actual_line,
                  description: message
                },
                __STACKTRACE__
    end
  end
end
