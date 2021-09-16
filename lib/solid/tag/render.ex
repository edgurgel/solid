defmodule Solid.Tag.Render do
  import NimbleParsec
  alias Solid.Parser.{Tag, Argument, Literal}

  @behaviour Solid.Tag

  @impl true
  def render(
        [render_exp: [template: template_binding, arguments: argument_binding]],
        context,
        options
      ) do
    template = Solid.Argument.get(template_binding, context)

    binding_vars =
      Keyword.get(argument_binding || [], :named_arguments, [])
      |> Solid.Argument.parse_named_arguments(context)
      |> Enum.concat()
      |> Map.new()

    {file_system, instance} = options[:file_system] || {Solid.BlankFileSystem, nil}

    template_str = file_system.read_template_file(template, instance)
    template = Solid.parse!(template_str, options)
    rendered_text = Solid.render(template, binding_vars, options)
    {[text: rendered_text], context}
  end

  @impl true
  def spec() do
    space = Literal.whitespace(min: 0)

    ignore(Tag.opening_tag())
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
    |> ignore(Tag.closing_tag())
    |> tag(:render_exp)
  end
end
