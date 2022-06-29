defmodule Solid.ErrorContext do
  defmodule UndefinedVariable do
    @enforce_keys [:variable]
    defstruct @enforce_keys
  end

  defmodule UndefinedFilter do
    @enforce_keys [:filter]
    defstruct @enforce_keys
  end

  defmodule EmptyWarning do
    @enforce_keys [:variable, :filter]
    defstruct @enforce_keys
  end

  defstruct errors: [], warnings: []

  @process_key Solid.ErrorContext

  def new! do
    Process.put(@process_key, %__MODULE__{})
  end

  def get do
    Process.get(@process_key)
  end

  def add_undefined_variable(key) do
    error = %UndefinedVariable{variable: Enum.join(key, ".")}
    add_entry_to_context(:errors, error)
  end

  def add_undefined_filter(filter) do
    error = %UndefinedFilter{filter: filter}
    add_entry_to_context(:errors, error)
  end

  def add_empty_warning(key, filters) do
    filter_names = Enum.map(filters, fn {:filter, [name, _opts]} -> name end)
    warning = %EmptyWarning{variable: Enum.join(key, "."), filter: filter_names}
    add_entry_to_context(:warnings, warning)
  end

  defp add_entry_to_context(field, entry) do
    error_ctx = Process.get(@process_key)

    if error_ctx do
      current = Map.get(error_ctx, field)
      error_ctx = %{error_ctx | field => current ++ [entry]}
      Process.put(@process_key, error_ctx)
    end
  end
end
