import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/shop start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :shop, ShopWeb.Endpoint, server: true
end

# The shop's name, shown in the header, page titles and email. The default
# is set in config/config.exs; SHOP_NAME overrides it in any environment.
if shop_name = System.get_env("SHOP_NAME") do
  config :shop, :shop_name, shop_name
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :shop, Shop.Repo,
    # RDS requires TLS and its CA is not in the runner image's trust store,
    # so encrypt the connection without verifying the chain.
    # Hosted databases (RDS) require TLS; a laptop's Postgres in
    # docker-compose.yml has none. DATABASE_SSL=false turns it off.
    ssl:
      if(System.get_env("DATABASE_SSL", "true") == "false",
        do: false,
        else: [verify: :verify_none]
      ),
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  # Links in emails and redirects. Hosting sits behind TLS on 443; a laptop
  # (docker-compose.yml) is plain http on the app's own port.
  url_config =
    case System.get_env("PHX_SCHEME") do
      "http" ->
        [host: host, port: String.to_integer(System.get_env("PORT") || "4000"), scheme: "http"]

      _ ->
        [host: host, port: 443, scheme: "https"]
    end

  port = String.to_integer(System.get_env("PORT") || "4000")

  config :shop, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :shop, ShopWeb.Endpoint,
    url: url_config,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :shop, ShopWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :shop, ShopWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # Transactional email (magic links) goes out through Amazon SES, signed
  # with the instance role's credentials: ExAws fetches them from instance
  # metadata, so no access key is configured anywhere. AWS_REGION is the
  # region SES is used in; ca-central-1 unless told otherwise.
  # MAIL_ADAPTER=logger prints outgoing mail (sign-in links included) to the
  # log instead of sending it: what docker-compose.yml uses on a laptop.
  case System.get_env("MAIL_ADAPTER") do
    "logger" -> config :shop, Shop.Mailer, adapter: Swoosh.Adapters.Logger, level: :info
    _ -> config :shop, Shop.Mailer, adapter: Swoosh.Adapters.ExAwsAmazonSES
  end

  config :shop, :mail_from, System.get_env("MAIL_FROM") || "noreply@#{host}"

  config :ex_aws,
    http_client: ExAws.Request.Req,
    json_codec: Jason,
    access_key_id: [:instance_role],
    secret_access_key: [:instance_role],
    region: System.get_env("AWS_REGION") || "ca-central-1"
end

config :shop, :website_preview_secret, System.get_env("WEBSITE_PREVIEW_SECRET")

config :shop, :media_bucket, System.get_env("MEDIA_BUCKET")
config :shop, :aws_credentials_file, System.get_env("AWS_CREDENTIALS_FILE")

config :shop,
       :trusted_proxy_ips,
       String.split(System.get_env("TRUSTED_PROXY_IPS") || "", ",", trim: true)

if System.get_env("AWS_CREDENTIALS_FILE") do
  config :shop, Shop.Mailer, adapter: Shop.MailAdapter
end
