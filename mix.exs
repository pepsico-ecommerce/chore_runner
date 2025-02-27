defmodule ChoreRunner.MixProject do
  @moduledoc false

  use Mix.Project

  def project do
    [
      app: :chore_runner,
      version: "0.5.4",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      description: """
      An Elixir library for writing and running code chores.
      """,
      aliases: aliases()
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
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_view, "~> 2.0"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_html_helpers, "~> 1.0"},
      {:telemetry, "~> 1.1"}
    ]
  end

  defp package do
    [
      maintainers: ["Chris Freeze"],
      licenses: ["Apache 2.0"],
      links: %{github: "https://github.com/pepsico-ecommerce/chore_runner"},
      files: ~w(lib priv/css mix.exs README.md CHANGELOG.md .formatter.exs)
    ]
  end

  defp aliases do
    [publish: ["hex.publish", &git_tag/1]]
  end

  defp git_tag(_args) do
    System.cmd("git", ["tag", "v" <> Mix.Project.config()[:version]])
    System.cmd("git", ["push", "--tags"])
  end
end
