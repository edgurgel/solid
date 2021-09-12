defmodule CustomTags do
  defmodule CurrentDate do
    import NimbleParsec
    alias Solid.Parser.Literal

    @behaviour Solid.Tag.CustomTag

    @impl true
    def spec() do
      space = Literal.whitespace(min: 0)

      ignore(string("{%"))
      |> ignore(space)
      |> ignore(string("get_current_date"))
      |> ignore(space)
      |> ignore(string("%}"))
    end

    def render(_context, _arguments) do
      DateTime.utc_now().year |> to_string
    end

    @impl true
    def render(_context, _arguments, _options) do
      [text: DateTime.utc_now().year |> to_string]
    end
  end

  defmodule GetYearOfDate do
    import NimbleParsec
    alias Solid.Parser.{Literal, Argument}

    @behaviour Solid.Tag.CustomTag

    @impl true
    def spec() do
      space = Literal.whitespace(min: 0)

      ignore(string("{%"))
      |> ignore(space)
      |> ignore(string("get_year"))
      |> ignore(space)
      |> tag(Argument.arguments(), :arguments)
      |> ignore(space)
      |> ignore(string("%}"))
    end

    def render(_context, arguments: [value: dt_str]) do
      {:ok, dt, _} = DateTime.from_iso8601(dt_str)
      "#{dt.year}-#{dt.month}-#{dt.day}"
    end

    def render(context, arguments: [field: [var_name]]) do
      dt_str = Map.fetch!(context.iteration_vars, var_name)
      {:ok, dt, _} = DateTime.from_iso8601(dt_str)
      "#{dt.year}-#{dt.month}-#{dt.day}"
    end

    @impl true
    def render(_context, [arguments: [value: dt_str]], _options) do
      {:ok, dt, _} = DateTime.from_iso8601(dt_str)
      [text: "#{dt.year}-#{dt.month}-#{dt.day}"]
    end

    @impl true
    def render(context, [arguments: [field: [var_name]]], _options) do
      dt_str = Map.fetch!(context.iteration_vars, var_name)
      {:ok, dt, _} = DateTime.from_iso8601(dt_str)
      [text: "#{dt.year}-#{dt.month}-#{dt.day}"]
    end
  end

  defmodule CustomBrackedWrappedTag do
    import NimbleParsec
    alias Solid.Parser.Literal

    @behaviour Solid.Tag.CustomTag

    @impl true
    def spec() do
      space = Literal.whitespace(min: 0)

      ignore(string("{%"))
      |> ignore(space)
      |> ignore(string("myblock"))
      |> ignore(space)
      |> ignore(string("%}"))
      |> tag(parsec(:liquid_entry), :result)
      |> ignore(string("{%"))
      |> ignore(space)
      |> ignore(string("endmyblock"))
      |> ignore(space)
      |> ignore(string("%}"))
    end

    @impl true
    def render(context, [result: result], options) do
      {text, _context} = Solid.render(result, context, options)
      [text: ["[[", text, "]]"]]
    end
  end

  defmodule FoobarTag do
    import NimbleParsec
    @behaviour Solid.Tag.CustomTag
    def spec() do
      space = Solid.Parser.Literal.whitespace(min: 0)

      ignore(string("{%"))
      |> ignore(space)
      |> ignore(string("foobar"))
      |> ignore(space)
      |> tag(optional(Solid.Parser.Argument.arguments()), :arguments)
      |> ignore(space)
      |> ignore(string("%}"))
    end

    def render(_context, _arguments, _opts) do
      "barbaz"
    end
  end

  defmodule FoobarValTag do
    import NimbleParsec
    @behaviour Solid.Tag.CustomTag

    def spec() do
      space = Solid.Parser.Literal.whitespace(min: 0)

      ignore(string("{%"))
      |> ignore(space)
      |> ignore(string("foobarval"))
      |> ignore(space)
      |> tag(optional(Solid.Parser.Argument.arguments()), :arguments)
      |> ignore(space)
      |> ignore(string("%}"))
    end

    def render(_context, [arguments: [value: string]], _opts) do
      "barbaz#{string}"
    end
  end
end
