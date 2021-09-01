defmodule CustomDateParser do
  use Solid.Parser.Base, custom_tags: ["current_date", "get_year_of_date"]
end

defmodule CustomFooParser do
  use Solid.Parser.Base, custom_tags: ["foobar", "foobarval"]
end

defmodule CustomPaddingParser do
  use Solid.Parser.Base, custom_tags: ["padding", "pad"]
end
