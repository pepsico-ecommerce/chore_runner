defmodule ChoreRunner.MixProject do
  @moduledoc false

  use Mix.Project

  def project do
    [
      app: :chore_runner,
      version: "0.7.1",
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
    [tag_release: &tag_release/1]
  end

  # Tags the current commit with the mix.exs version and pushes only that tag.
  defp tag_release(_args) do
    tag = "v" <> Mix.Project.config()[:version]

    git!(["fetch", "origin", "master", "--tags"])

    if git!(["branch", "--show-current"]) != "master",
      do: Mix.raise("Releases must be cut from master")

    if git!(["status", "--porcelain", "--untracked-files=no"]) != "",
      do: Mix.raise("Working tree is not clean")

    if git!(["rev-parse", "HEAD"]) != git!(["rev-parse", "origin/master"]),
      do: Mix.raise("Local master is not in sync with origin/master")

    if git!(["tag", "-l", tag]) != "",
      do: Mix.raise("Tag #{tag} already exists")

    unless File.read!("CHANGELOG.md") =~ "## #{tag} (",
      do: Mix.raise("CHANGELOG.md has no ## #{tag} (YYYY-MM-DD) section")

    git!(["tag", tag])
    git!(["push", "origin", tag])
    Mix.shell().info("Pushed #{tag}")
  end

  defp git!(args) do
    case System.cmd("git", args, stderr_to_stdout: true) do
      {output, 0} -> String.trim(output)
      {output, _} -> Mix.raise("git #{Enum.join(args, " ")} failed:\n#{output}")
    end
  end
end
