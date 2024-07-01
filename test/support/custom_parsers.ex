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

defmodule NoRenderParser do
  use Solid.Parser.Base, excluded_tags: [Solid.Tag.Render]
end

defmodule Parser do
  use Solid.Parser.Base,
    excluded_tags: [
      Solid.Tag.Break,
      Solid.Tag.Continue,
      Solid.Tag.Counter,
      Solid.Tag.Comment,
      Solid.Tag.Assign,
      Solid.Tag.Capture,
      Solid.Tag.If,
      Solid.Tag.Case,
      Solid.Tag.For,
      Solid.Tag.Raw,
      Solid.Tag.Cycle,
      Solid.Tag.Render
    ]
end
