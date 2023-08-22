defmodule Solid.Caching do
  @callback get(key :: term) :: {:ok, Template.t()} | {:error, :not_found}

  @callback put(key :: term, Template.t()) :: :ok | {:error, term}
end
