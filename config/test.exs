import Config
config :xo, token_signing_secret: "5hw+u+BKFx0+lT7eA3KKurfHcPyXeqS5"
config :bcrypt_elixir, log_rounds: 1
config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :xo, Xo.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "xo_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :xo, XoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "PzJ2J/2AOUTHJMSTvRfnAaDnDfNBzb6L6e7FZ7DodhZJp6npkvz0He9rqZd51KI0",
  server: false

# In test we don't send emails
config :xo, Xo.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Disable the AI commentator in tests (it spawns processes that can't access the sandbox)
config :xo, commentator_enabled: false

# Enable bot server in tests with a shorter delay
config :xo, :bot_enabled, true
config :xo, :bot_delay_ms, 100

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
