import Config

# Configure your database for testing
config :data, Data.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "elixir_game_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :data, :ecto_repos, [Data.Repo]

# Configure ETS for testing
config :utils, Utils.ETS,
  tables: [:users]

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :web, Web.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "PLLqtRuKtF/AFfnf9KXHa7Mf4xSxUIN+TGrzOq4mQYjWjdqlfgCCPZf1PWMEblvS",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning
