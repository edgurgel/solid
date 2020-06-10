defmodule Solid.Mixfile do
  use Mix.Project

  @description """
    Liquid Template engine
  """

  def project do
    [
      app: :solid,
      version: "0.5.0",
      elixir: "~> 1.9",
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
      {:nimble_parsec, "~> 0.5.1"},
      {:poison, "~> 4.0", only: :test},
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
end
