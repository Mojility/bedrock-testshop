# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :business, :scopes,
  user: [
    default: true,
    module: Business.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :binary_id,
    schema_table: :users,
    test_data_fixture: Business.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :business,
  ecto_repos: [Business.Repo],
  generators: [timestamp_type: :utc_datetime]

# Fallback for an unconfigured starter. Generated names are data, never source.
# Existing systems may retain their baked-in name here; runtime preserves it
# when priv/business.json and the environment overrides are absent.
config :business, :business_name, "Business"

# Sender of every email the system sends. Production reads MAIL_FROM.
config :business, :mail_from, "noreply@localhost"

# Configures the endpoint
config :business, BusinessWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: BusinessWeb.ErrorHTML, json: BusinessWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Business.PubSub,
  live_view: [signing_salt: "vc6QTUuk"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :business, Business.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.28.2",
  business: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.3",
  business: [
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
