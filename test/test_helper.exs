ExUnit.start()
{:module, _} = Code.ensure_compiled(Solid.CustomFilters)

defmodule Solid.Helpers do
  use Solid, delegates: false

  def render(text, hash \\ %{}, options \\ []) do
    case Solid.parse(text, options) do
      {:ok, template} ->
        template
        |> Solid.render(hash, options)
        |> case do
          {:error, errors, result} -> {:error, errors, to_string(result)}
          {:ok, result} -> to_string(result)
          result -> to_string(result)
        end

      {:error, error} ->
        inspect(error)
    end
  rescue
    e ->
      IO.puts(Exception.format(:error, e, __STACKTRACE__))
      inspect(e)
  end

  def liquid_render(input_liquid, input_json, template_dir) do
    if template_dir do
      System.cmd("ruby", ["test/liquid.rb", input_liquid, input_json, template_dir])
    else
      System.cmd("ruby", ["test/liquid.rb", input_liquid, input_json])
    end
  end

  defmacro assert_render(liquid_input, json_input, template_dir, opts \\ []) do
    quote do
      opts =
        if unquote(template_dir) do
          file_system = Solid.LocalFileSystem.new(unquote(template_dir))
          [{:file_system, {Solid.LocalFileSystem, file_system}} | unquote(opts)]
        else
          unquote(opts)
        end

      solid_output =
        render(unquote(liquid_input), Jason.decode!(unquote(json_input)), opts)
        |> IO.iodata_to_binary()

      {liquid_output, 0} =
        liquid_render(unquote(liquid_input), unquote(json_input), unquote(template_dir))

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
