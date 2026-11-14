defmodule Solid.RootLookupMatcher do
  @moduledoc """
  A custom `matcher_module` that looks up the root name in a plain-map scope itself and hands
  the rest of the path to `Solid.Matcher`, as the README recommends.

  Integration scenarios render with it too: such a matcher must render exactly like the
  default one, and so like Ruby Liquid.
  """
  def match(data, [root | keys]) when is_map(data) and not is_struct(data) do
    case Map.fetch(data, root) do
      {:ok, value} -> Solid.Matcher.match(value, keys)
      :error -> {:error, :not_found}
    end
  end

  def match(data, keys), do: Solid.Matcher.match(data, keys)
end
