defmodule CustomDateParser do
  use Solid.Parser.Base,
    custom_tags: [
      "current_date",
      "get_year_of_date",
      {"get_current_date", CustomTags.CurrentDate},
      {"get_year", CustomTags.GetYearOfDate}
    ]
end

defmodule CustomFooParser do
  use Solid.Parser.Base, custom_tags: ["foobar", "foobarval"]
end
