defmodule Solid.Helpers.TemplateResolver do
  @moduledoc false

  @doc """
  Lookup for given template with rules

  - If it's relative path start with `../`, only lookup relative to `current_dir`
  - Otherwise lookup in order `current_dir` -> `lookup_dir`

  - First lookup template with exact given name, if not found then append `.liquid` extension and lookup again.

  And stop at first found template.
  """
  @spec lookup(String.t(), String.t() | nil, list()) ::
          {:ok, String.t()} | {:error, :not_found}
  def lookup(template, current_dir, lookup_dir) do
    if String.starts_with?(template, "..") do
      lookup_template(template, [current_dir])
    else
      lookup_template(template, [current_dir] ++ List.wrap(lookup_dir))
    end
  end

  defp lookup_template(template, [lookup_dir | t]) do
    case lookup_template(template, lookup_dir) do
      {:ok, path} -> {:ok, path}
      _error -> lookup_template(template, t)
    end
  end

  defp lookup_template(_, []), do: {:error, :not_found}
  defp lookup_template(_, nil), do: {:error, :not_found}

  defp lookup_template(template, lookup_dir) do
    path1 = Path.expand(template, lookup_dir)

    path2 = Path.expand("#{template}.liquid", lookup_dir)

    cond do
      File.exists?(path1, raw: true) ->
        {:ok, path1}

      File.exists?(path2, raw: true) ->
        {:ok, path2}

      true ->
        {:error, :not_found}
    end
  end
end
