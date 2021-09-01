defmodule CustomDateParser do
  use Solid.Parser.Base, custom_tags: ["current_date", "get_year_of_date"]
end

defmodule CustomFooParser do
  use Solid.Parser.Base, custom_tags: ["foobar", "foobarval"]
end

defmodule CustomIncludeParser do
  use Solid.Parser.Base

  space = string(" ") |> times(min: 0)

  include =
    ignore(string("{%"))
    |> ignore(space)
    |> concat(string("include"))
    |> ignore(space)
    |> tag(@argument, :template)
    |> optional(
      ignore(string(","))
      |> ignore(space)
      |> concat(@named_arguments)
      |> tag(:arguments)
    )
    |> ignore(space)
    |> ignore(string("%}"))
    |> tag(:custom_tag)

  @custom_tags [include]
end
