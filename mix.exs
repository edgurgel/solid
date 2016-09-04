defmodule Solid.Mixfile do
  use Mix.Project

  @description """
    Liquid Template engine
  """

  @compile_peg_task "tasks/compile.peg.exs"
  @do_peg_compile?  File.exists?(@compile_peg_task)
  if @do_peg_compile? do
    Code.eval_file @compile_peg_task
  end

  def project do
    [app: :solid,
     version: "0.0.1",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     compilers: [:peg, :erlang, :elixir, :app],
     name: "solid",
     description: @description,
     package: package,
     deps: deps]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [{:neotoma, "~> 1.7.3"},
     {:earmark, "~> 1.0", only: :dev},
     {:ex_doc, "~> 0.13", only: :dev}]
  end

  defp package do
    [ maintainers: ["Eduardo Gurgel Pinho"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/edgurgel/solid"} ]
  end
end
