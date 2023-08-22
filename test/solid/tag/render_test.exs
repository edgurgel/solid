defmodule Solid.Tag.RenderTest do
  use ExUnit.Case, async: true
  alias Solid.Tag.Render
  alias Solid.Context

  defmodule Parser do
    import NimbleParsec
    defparsec(:parse, Render.spec(__MODULE__) |> eos())
  end

  defmodule TestCache do
    use Agent
    @behaviour Solid.Caching

    def start_link(_opts) do
      Agent.start_link(fn -> %{} end, name: __MODULE__)
    end

    @impl true
    def put(cache_key, value) do
      Agent.update(__MODULE__, &Map.put(&1, cache_key, value))

      :ok
    end

    @impl true
    def get(cache_key) do
      Agent.get(__MODULE__, &Map.get(&1, cache_key, {:error, :not_found}))
    end

    def get_all() do
      Agent.get(__MODULE__, & &1)
    end
  end

  defmodule Test.SolidFileSystem do
    @behaviour Solid.FileSystem

    @impl true
    def read_template_file("second", _opts) do
      "hello there"
    end

    @impl true
    def read_template_file("broken", _opts) do
      "{% {{"
    end
  end

  setup do
    {:ok, cache} = TestCache.start_link([])
    %{cache: cache}
  end

  test "must store cache" do
    {:ok, parsed, _, _, _, _} =
      ~s({% render "second" %}) |> Parser.parse(file_system: {Test.SolidFileSystem, nil})

    assert {[text: [["hello there"]]], %Context{}} ==
             Render.render(parsed, %Context{},
               cache_module: TestCache,
               file_system: {Test.SolidFileSystem, nil}
             )

    calculated_cache_key = :md5 |> :crypto.hash("hello there") |> Base.encode16(case: :lower)

    assert %{calculated_cache_key => %Solid.Template{parsed_template: [text: ["hello there"]]}} ==
             TestCache.get_all()
  end

  test "must correctly return error from parsing" do
    {:ok, parsed, _, _, _, _} =
      ~s({% render "broken" %}) |> Parser.parse(file_system: {Test.SolidFileSystem, nil})

    assert {[],
            %Solid.Context{
              counter_vars: %{},
              cycle_state: %{},
              errors: [
                %Solid.TemplateError{
                  header: "{% {{",
                  line: {1, 0},
                  message: "Reason: expected end of string, line: 1, header: {% {{",
                  reason: "expected end of string"
                }
              ],
              iteration_vars: %{},
              vars: %{}
            }} == Render.render(parsed, %Context{}, file_system: {Test.SolidFileSystem, nil})
  end
end
