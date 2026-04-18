import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :o_grupo_de_estudos, OGrupoDeEstudos.Repo,
  username: "forrozin",
  password: "forrozin",
  hostname: "localhost",
  port: 5433,
  database: "o_grupo_de_estudos_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :o_grupo_de_estudos, OGrupoDeEstudosWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "+D0l4D3qh4QSxtT8/4wdqL0LWDmwWUOTbyx5P3aMptFpJGdF9njMcxwp03N65xHb",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Oban — executa jobs sincronamente nos testes
config :o_grupo_de_estudos, Oban, testing: :inline

# Mailer — captura emails nos testes via Swoosh.TestAssertions
config :o_grupo_de_estudos, OGrupoDeEstudos.Mailer, adapter: Swoosh.Adapters.Test

# Avoid DB writes from detached processes during SQL Sandbox tests.
config :o_grupo_de_estudos,
  async_device_tracking: false,
  persist_error_logs: false
