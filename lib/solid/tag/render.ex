defmodule Solid.Tag.Render do
  import NimbleParsec
  alias Solid.Parser.{BaseTag, Argument, Literal}

  @behaviour Solid.Tag

  @impl true
  def spec(_parser) do
    space = Literal.whitespace(min: 0)

    ignore(BaseTag.opening_tag())
    |> ignore(string("render"))
    |> ignore(space)
    |> tag(Argument.argument(), :template)
    |> tag(
      optional(
        ignore(string(","))
        |> ignore(space)
        |> concat(Argument.named_arguments())
      ),
      :arguments
    )
    |> ignore(space)
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render(
        [template: template_binding, arguments: argument_binding],
        context,
        options
      ) do
    template = Solid.Argument.get(template_binding, context, allow_undefined?: true)

    binding_vars =
      Keyword.get(argument_binding || [], :named_arguments, [])
      |> Solid.Argument.parse_named_arguments(context)
      |> Enum.concat()
      |> Map.new()

    {file_system, instance} = options[:file_system] || {Solid.BlankFileSystem, nil}

    template_str = file_system.read_template_file(template, instance)
    template = Solid.parse!(template_str, options)
    rendered_text = Solid.render(template, binding_vars, Keyword.merge(options, nested?: true))
    {[text: rendered_text], context}
  end
end
