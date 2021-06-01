ExUnit.start()

defmodule Solid.Helpers do
  def render(text, hash \\ %{}, options \\ []) do
    case Solid.parse(text, options) do
      {:ok, template} ->
        template
        |> Solid.render(hash, options)
        |> to_string()

      {:error, error} ->
        inspect(error)
    end
  rescue
    e ->
      IO.puts(Exception.format(:error, e, __STACKTRACE__))
      inspect(e)
  end

  def liquid_render(input_liquid, input_json) do
    System.cmd("ruby", ["test/liquid.rb", input_liquid, input_json])
  end

  defmacro assert_render(liquid_input, json_input) do
    quote do
      solid_output =
        render(unquote(liquid_input), Jason.decode!(unquote(json_input)), [])
        |> IO.iodata_to_binary()

      {liquid_output, 0} = liquid_render(unquote(liquid_input), unquote(json_input))

      if liquid_output == solid_output do
        true
      else
        message = """
        Render result was different!
        Input:
        #{unquote(liquid_input)}
        """

        expr =
          quote do
            liquid_output == solid_output
          end

        raise ExUnit.AssertionError,
          expr: expr,
          left: liquid_output,
          right: solid_output,
          message: message
      end
    end
  end
end
