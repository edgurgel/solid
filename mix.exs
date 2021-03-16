defmodule Solid.Mixfile do
  use Mix.Project

  @description """
    Liquid Template engine
  """

  def project do
    [
      app: :solid,
      version: "0.7.1",
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      name: "solid",
      description: @description,
      package: package(),
      docs: [
        main: "readme",
        extras: [
          "README.md"
        ]
      ],
      deps: deps()
    ]
  end

  def application, do: []

  defp deps do
    [
      {:nimble_parsec, "~> 1.0"},
      {:jason, "~> 1.0", only: :test},
      {:earmark, "~> 1.3", only: :dev},
      {:ex_doc, "~> 0.21", only: :dev}
    ]
  end

  defp package do
    [
      maintainers: ["Eduardo Gurgel Pinho"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/edgurgel/solid"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
