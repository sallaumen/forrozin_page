import Config

# A quarter of the cores, so a full run leaves the machine usable. ExUnit
# defaults to TWICE the cores, which on a dev laptop means the suite competes
# with the editor and the browser. `test/test_helper.exs` caps the VM schedulers
# to match, otherwise the BEAM still spreads over every core.
#
# CI raises both with TEST_MAX_CASES, where the machine has nothing else to do.
max_cases =
  case System.get_env("TEST_MAX_CASES") do
    nil -> max(div(System.schedulers_online(), 4), 2)
    value -> String.to_integer(value)
  end

config :ex_unit, max_cases: max_cases
config :o_grupo_de_estudos, :test_max_cases, max_cases

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
  # One connection per concurrent case, plus room for the ones that check out
  # a second connection (Oban, Presence).
  pool_size: max_cases + 4

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

# Oban: runs jobs synchronously in tests
config :o_grupo_de_estudos, Oban, testing: :inline

# Uploads in a disposable directory. Tests that need to inspect a file swap
# this key for a tmp of their own.
config :o_grupo_de_estudos, :uploads_path, Path.expand("../tmp/test_uploads", __DIR__)

# Video: by default the suite runs as a machine with no ffmpeg, so it does not
# depend on an installed binary. The transcode test swaps in the Mox mock.
config :o_grupo_de_estudos, OGrupoDeEstudos.Media.Video,
  adapter: OGrupoDeEstudos.Media.Video.NotInstalled

# Mailer: captures emails in tests through Swoosh.TestAssertions
config :o_grupo_de_estudos, OGrupoDeEstudos.Mailer, adapter: Swoosh.Adapters.Test

# Avoid DB writes from detached processes during SQL Sandbox tests.
config :o_grupo_de_estudos,
  env: :test,
  async_device_tracking: false,
  persist_error_logs: false,
  # TTL 0: every call queries the database, preserving the sandbox isolation.
  admin_ids_cache_ttl_ms: 0
