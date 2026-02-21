# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :riak_dashboard,
  generators: [timestamp_type: :utc_datetime]

config :riak_dashboard, :basic_auth,
  username: "admin",
  password: "password"

config :riak_dashboard, :riak_admin_url, "http://localhost:8099"
config :riak_dashboard, :riak_ws_url, "ws://localhost:8099/api/stream/events"

# Configures the endpoint
config :riak_dashboard, RiakDashboardWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: RiakDashboardWeb.ErrorHTML, json: RiakDashboardWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: RiakDashboard.PubSub,
  live_view: [signing_salt: "t0nfS69j"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  riak_dashboard: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.0.9",
  riak_dashboard: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
