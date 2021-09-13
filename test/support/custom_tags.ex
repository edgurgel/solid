defmodule CustomTags do
  defmodule CurrentDate do
    import NimbleParsec
    alias Solid.Parser.{Literal, Tag}

    @behaviour Solid.Tag

    @impl true
    def spec() do
      ignore(Tag.opening_tag())
      |> ignore(string("get_current_date"))
      |> ignore(Tag.closing_tag())
    end

    @impl true
    def render(_arguments, _context, _options) do
      DateTime.utc_now().year |> to_string
    end
  end

  defmodule GetYearOfDate do
    import NimbleParsec
    alias Solid.Parser.{Literal, Argument, Tag}

    @behaviour Solid.Tag

    @impl true
    def spec() do
      space = Literal.whitespace(min: 0)

      ignore(Tag.opening_tag())
      |> ignore(string("get_year"))
      |> ignore(space)
      |> tag(Argument.arguments(), :arguments)
      |> ignore(Tag.closing_tag())
    end

    @impl true
    def render([arguments: [value: dt_str]], _context, _options) do
      {:ok, dt, _} = DateTime.from_iso8601(dt_str)
      "#{dt.year}-#{dt.month}-#{dt.day}"
    end

    def render([arguments: [field: [var_name]]], context, _options) do
      dt_str = Map.fetch!(context.iteration_vars, var_name)
      {:ok, dt, _} = DateTime.from_iso8601(dt_str)
      "#{dt.year}-#{dt.month}-#{dt.day}"
    end
  end

  defmodule CustomBrackedWrappedTag do
    import NimbleParsec
    alias Solid.Parser.{Literal, Tag}

    @behaviour Solid.Tag

    @impl true
    def spec() do
      space = Literal.whitespace(min: 0)

      ignore(Tag.opening_tag())
      |> ignore(string("myblock"))
      |> ignore(Tag.closing_tag())
      |> tag(parsec(:liquid_entry), :result)
      |> ignore(Tag.opening_tag())
      |> ignore(space)
      |> ignore(string("endmyblock"))
      |> ignore(Tag.closing_tag())
    end

    @impl true
    def render([result: result], context, options) do
      {text, context} = Solid.render(result, context, options)
      {[text: ["[[", text, "]]"]], context}
    end
  end

  defmodule FoobarTag do
    @behaviour Solid.Tag

    @impl true
    def spec(), do: Solid.Tag.basic("foobar")

    @impl true
    def render(_arguments, _context, _opts) do
      "barbaz"
    end
  end

  defmodule FoobarValTag do
    @behaviour Solid.Tag

    @impl true
    def spec(), do: Solid.Tag.basic("foobarval")

    @impl true
    def render([arguments: [value: string]], _context, _opts) do
      "barbaz#{string}"
    end
  end
end
