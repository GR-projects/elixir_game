import Config

config :web, Web.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "PLLqtRuKtF/AFfnf9KXHa7Mf4xSxUIN+TGrzOq4mQYjWjdqlfgCCPZf1PWMEblvS",
  server: false

config :delayed_tasks,
  persistence_enabled: false
