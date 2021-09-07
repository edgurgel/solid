defmodule CustomTags do
  defmodule CurrentDate do
    import NimbleParsec
    alias Solid.Parser.Literal

    @behaviour Solid.Tag.CustomTag

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

    def render(_context, _arguments, _options) do
      DateTime.utc_now().year |> to_string
    end
  end

  defmodule GetYearOfDate do
    import NimbleParsec
    alias Solid.Parser.{Literal, Argument}

    @behaviour Solid.Tag.CustomTag

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

    def render(_context, [arguments: [value: dt_str]], _options) do
      {:ok, dt, _} = DateTime.from_iso8601(dt_str)
      "#{dt.year}-#{dt.month}-#{dt.day}"
    end

    def render(context, [arguments: [field: [var_name]]], _options) do
      dt_str = Map.fetch!(context.iteration_vars, var_name)
      {:ok, dt, _} = DateTime.from_iso8601(dt_str)
      "#{dt.year}-#{dt.month}-#{dt.day}"
    end
  end
end
