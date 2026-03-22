defmodule DelayedTasks.MixProject do
  use Mix.Project

  def project do
    [
      app: :delayed_tasks,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {DelayedTasks.Application, []}
    ]
  end

  defp deps do
    [
      # Dependencies for database operations
      {:ecto_sql, "~> 3.10"},
      {:jason, "~> 1.4"},
      # Test dependencies
      {:mox, "~> 1.0", only: :test}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
