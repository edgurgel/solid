defmodule Solid.ErrorContext do
  defmodule UndefinedVariable do
    @enforce_keys [:variable]
    defstruct @enforce_keys
  end

  defmodule UndefinedFilter do
    @enforce_keys [:filter]
    defstruct @enforce_keys
  end

  defstruct errors: []

  @process_key Solid.ErrorContext

  def new! do
    Process.put(@process_key, %__MODULE__{})
  end

  def get do
    Process.get(@process_key)
  end

  def add_undefined_variable(key) do
    error = %UndefinedVariable{variable: Enum.join(key, ".")}
    error_ctx = Process.get(@process_key)

    if error_ctx do
      error_ctx = %{error_ctx | errors: error_ctx.errors ++ [error]}
      Process.put(@process_key, error_ctx)
    end
  end

  def add_undefined_filter(filter) do
    error = %UndefinedFilter{filter: filter}
    error_ctx = Process.get(@process_key)

    if error_ctx do
      error_ctx = %{error_ctx | errors: error_ctx.errors ++ [error]}
      Process.put(@process_key, error_ctx)
    end
  end
end
