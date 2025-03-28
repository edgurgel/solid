defprotocol Solid.Renderable do
  @spec render(t, Solid.Context.t(), Keyword.t()) ::
          {binary | iolist | [t], Solid.Context.t()}
  def render(value, context, options)
end
