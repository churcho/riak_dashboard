import Config

config :riak_dashboard, :cluster_client, RiakDashboard.Cluster.MockBehaviour

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :riak_dashboard, RiakDashboardWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "9VruDgb3aaanpeKdModWv73+VI3NVHQ4HqAGB4ygUrYl7TYnyCiaoM0uLSvo5+M4",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
