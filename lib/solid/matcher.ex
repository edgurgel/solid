defprotocol Solid.Matcher do
  @fallback_to_any true
  @doc "Assigns context to values"
  def match(_, _)
end

defimpl Solid.Matcher, for: Any do
  def match(data, []), do: {:ok, data}

  def match(_, _), do: {:error, :not_found}
end

defimpl Solid.Matcher, for: List do
  def match(data, []), do: {:ok, data}

  def match(data, ["size"]) do
    {:ok, Enum.count(data)}
  end

  def match(data, [key | keys]) when is_integer(key) do
    case Enum.fetch(data, key) do
      {:ok, value} -> @protocol.match(value, keys)
      _ -> {:error, :not_found}
    end
  end
end

defimpl Solid.Matcher, for: Map do
  def match(data, []) do
    {:ok, data}
  end

  def match(data, ["size"]) do
    {:ok, Map.get(data, "size", Enum.count(data))}
  end

  def match(data, [key | []]) do
    case Map.fetch(data, key) do
      {:ok, value} when is_function(value, 1) ->
        case value.(data) do
          {:ok, value} -> {:ok, value}
          _ -> {:error, :not_found}
        end

      {:ok, value} when not is_function(value) ->
        {:ok, value}

      _ ->
        {:error, :not_found}
    end
  end

  def match(data, [key | keys]) do
    case Map.fetch(data, key) do
      {:ok, value} when is_function(value, 1) ->
        case value.(data) do
          {:ok, value} -> @protocol.match(value, keys)
          _ -> {:error, :not_found}
        end

      {:ok, value} when not is_function(value) ->
        @protocol.match(value, keys)

      _ ->
        {:error, :not_found}
    end
  end
end

defimpl Solid.Matcher, for: BitString do
  def match(current, []), do: {:ok, current}

  def match(data, ["size"]) do
    {:ok, String.length(data)}
  end

  def match(_data, [i | _]) when is_integer(i) do
    {:error, :not_found}
  end

  def match(_data, [i | _]) when is_binary(i) do
    {:error, :not_found}
  end
end

defimpl Solid.Matcher, for: Atom do
  def match(current, []) when is_nil(current), do: {:ok, nil}
  def match(data, []), do: {:ok, data}
  def match(nil, _), do: {:error, :not_found}

  @doc """
  Matches all remaining cases
  """
  def match(_current, [key]) when is_binary(key), do: {:error, :not_found}
end
