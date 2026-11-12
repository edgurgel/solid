defmodule Solid.MatcherNotImplementedError do
  @moduledoc """
  Reported when a variable lookup reaches a struct that does not implement
  `Solid.Matcher` and there are still keys left to resolve.

  Only collected when `strict_variables: true`.
  """
  @type t :: %__MODULE__{}
  defexception [:struct, :variable, :original_name, :loc]

  @impl true
  def message(exception) do
    line = exception.loc.line

    reason =
      "Protocol Solid.Matcher not implemented for #{inspect(exception.struct)} (#{exception.original_name})"

    "#{line}: #{reason}"
  end
end
