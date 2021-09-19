defmodule CustomDateParser do
  use Solid.Parser.Base,
    custom_tags: [
      CustomTags.CurrentDate,
      CustomTags.GetYearOfDate,
      CustomTags.CustomBrackedWrappedTag
    ]
end

defmodule CustomFooParser do
  use Solid.Parser.Base,
    custom_tags: [CustomTags.FoobarTag, CustomTags.FoobarValTag]
end
