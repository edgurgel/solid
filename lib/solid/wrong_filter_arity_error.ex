defmodule Solid.WrongFilterArityError do
  @type t :: %__MODULE__{}
  defexception [:filter, :expected_arity, :arity, :loc]

  @impl true
  def message(exception) do
    "Liquid error (line #{exception.loc.line}): wrong number of arguments (given #{exception.arity}, expected #{exception.expected_arity})"
  end
end
