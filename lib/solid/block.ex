defprotocol Solid.Block do
  @fallback_to_any true
  @spec blank?(t) :: boolean
  def blank?(body)
end

defimpl Solid.Block, for: Any do
  def blank?(_body), do: false
end

defimpl Solid.Block, for: List do
  def blank?(list), do: Enum.all?(list, &Solid.Block.blank?/1)
end
