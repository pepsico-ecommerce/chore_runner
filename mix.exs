defmodule ChoreRunner.MixProject do
  use Mix.Project

  def project do
    [
      app: :chore_runner,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      description: """
      An Elixir library for writing and running code chores.
      """
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:phoenix_live_view, "~> 0.16.3"},
      {:floki, ">= 0.30.0", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["Chris Freeze"],
      licenses: ["Apache 2.0"],
      links: %{github: "https://github.com/pepsico-ecommerce/chore_runner"},
      files: ~w(lib priv/css mix.exs README.md .formatter.exs)
    ]
  end
end
