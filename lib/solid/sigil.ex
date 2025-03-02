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
  """

  # Import Solid to use parse! function
  require Solid

  # Custom sigil for validating and compiling Liquid templates using Solid
  defmacro sigil_LIQUID({:<<>>, _meta, [string]}, _modifiers) do
    line = __CALLER__.line
    file = __CALLER__.file

    try do
      # Validate the template during compile time
      parsed_template = Solid.parse!(string)

      # Return the parsed template
      Macro.escape(parsed_template)
    rescue
      e in Solid.TemplateError ->
        # Extract template line number (first element of the tuple)
        template_line = elem(e.line, 0)
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

        Error: #{e.reason}
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
