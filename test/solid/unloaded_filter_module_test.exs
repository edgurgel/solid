defmodule Solid.UnloadedFilterModuleTest do
  # async: false — touches the global code path and atom table.
  use ExUnit.Case, async: false

  # A custom filter used to be resolved with String.to_existing_atom/1. That
  # raises when the atom doesn't exist yet, and a filter module's function-name
  # atoms only exist once the module is loaded. With lazy code loading a valid
  # filter could therefore be dropped (passed through, with strict_filters off)
  # depending on whether anything had loaded the module first — so the same test
  # passed or failed by load order.
  #
  # To hit that state on purpose we compile the filter module in a separate OS
  # process (so its atoms never reach this VM) and add it to the code path
  # without loading it.
  test "applies a filter from a module that hasn't been loaded yet" do
    tmp =
      Path.join(System.tmp_dir!(), "solid_unloaded_filter_#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp)
    source = Path.join(tmp, "fixture.ex")

    # The function name only appears as a string here, so :shout is not interned
    # in this VM until the module is actually loaded.
    File.write!(source, """
    defmodule Solid.UnloadedFilterFixture do
      def shout(input), do: String.upcase(to_string(input)) <> "!"
    end
    """)

    {out, status} =
      System.cmd("elixirc", ["--no-docs", "-o", tmp, source], stderr_to_stdout: true)

    assert status == 0, out

    module = String.to_atom("Elixir.Solid.UnloadedFilterFixture")

    on_exit(fn ->
      :code.purge(module)
      :code.delete(module)
      :code.del_path(String.to_charlist(tmp))
      File.rm_rf!(tmp)
    end)

    :code.add_pathz(String.to_charlist(tmp))

    # Sanity check we're actually reproducing the bug's preconditions.
    refute :code.is_loaded(module)
    assert_raise ArgumentError, fn -> String.to_existing_atom("shout") end

    rendered =
      "{{ name | shout }}"
      |> Solid.parse!()
      |> Solid.render!(%{"name" => "hi"}, custom_filters: module)
      |> to_string()

    assert rendered == "HI!"
  end
end
