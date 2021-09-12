defmodule CustomDateParser do
  use Solid.Parser.Base,
    custom_tags: [
      get_current_date: CustomTags.CurrentDate,
      get_year: CustomTags.GetYearOfDate,
      myblock: CustomTags.CustomBrackedWrappedTag
    ]
end

defmodule CustomFooParser do
  use Solid.Parser.Base,
    custom_tags: [
      foobar: CustomTags.FoobarTag,
      foobarval: CustomTags.FoobarValTag
    ]
end
