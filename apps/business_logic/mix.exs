defmodule BusinessLogic.MixProject do
  use Mix.Project

  def project do
    [
      app: :business_logic,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {BusinessLogic.Application, []},
      start_phases: [register_handlers: []]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.2.0"},
      {:jason, "~> 1.4"},
      {:data, in_umbrella: true},
      {:delayed_tasks, in_umbrella: true}
    ]
  end
end
