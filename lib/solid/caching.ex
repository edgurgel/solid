defmodule Solid.Caching do
  @callback get(key :: term) :: {:ok, Solid.Template.t()} | {:error, :not_found}

  @callback put(key :: term, Solid.Template.t()) :: :ok | {:error, term}
end
