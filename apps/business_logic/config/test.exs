import Config

# Configure your database
config :business_logic, BusinessLogic.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "business_logic_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :business_logic, BusinessLogicWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_for_testing_purposes_only_do_not_use_in_production",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
