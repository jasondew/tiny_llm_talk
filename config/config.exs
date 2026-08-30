# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# The deck quotes the model's source at request time rather than copying it,
# so `source_root` points at the sibling checkout the path dependency uses.
# The repo link sits in the footer of every slide.
config :tiny_llm_talk,
  source_root: "../tiny_llm",
  repo_url: "https://github.com/jasondew/tiny_llm",
  repo_label: "github.com/jasondew/tiny_llm"

config :tiny_llm_talk,
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :tiny_llm_talk, TinyLlmTalkWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: TinyLlmTalkWeb.ErrorHTML, json: TinyLlmTalkWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: TinyLlmTalk.PubSub,
  live_view: [signing_salt: "yBP/sord"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  tiny_llm_talk: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.0",
  tiny_llm_talk: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
