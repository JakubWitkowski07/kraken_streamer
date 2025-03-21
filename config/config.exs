# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :kraken_streamer,
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :kraken_streamer, KrakenStreamerWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: KrakenStreamerWeb.ErrorHTML, json: KrakenStreamerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: KrakenStreamer.PubSub,
  live_view: [signing_salt: "sNiUEeXQ"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  kraken_streamer: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  kraken_streamer: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :kraken_streamer, KrakenStreamer.KrakenAPI.Client,
  url: "https://api.kraken.com/0/public/AssetPairs"

config :kraken_streamer, KrakenStreamer.Pairs.Manager,
  check_interval: 600_000

config :kraken_streamer, KrakenStreamer.Pairs.Subscription,
  batch_delay: 200

config :kraken_streamer, KrakenStreamer.Pairs.Utilities,
  batch_size: 250

config :kraken_streamer, KrakenStreamer.Websocket.Client,
  url: "wss://ws.kraken.com/v2",
  ping_interval: 2000,
  tickers_update_interval: 1000

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
