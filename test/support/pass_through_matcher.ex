defmodule Solid.PassThroughMatcher do
  @moduledoc """
  A custom `matcher_module` that hands every lookup to `Solid.Matcher`.

  Integration scenarios render with it too: a custom matcher that adds nothing must render
  exactly like the default one, and so like Ruby Liquid.
  """
  def match(data, keys), do: Solid.Matcher.match(data, keys)
end
