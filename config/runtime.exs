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
#     PHX_SERVER=true bin/o_grupo_de_estudos start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :o_grupo_de_estudos, OGrupoDeEstudosWeb.Endpoint, server: true
end

config :o_grupo_de_estudos, OGrupoDeEstudosWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# Object storage on Cloudflare R2, switched on by the presence of the secrets:
# with them, EVERY new upload (avatar, flyer, gallery) goes to R2; without them,
# the local disk still holds. Outside :test on purpose: the suite controls the
# adapter on its own, and an env exported on the machine must not change how the
# tests behave.
if System.get_env("R2_ACCOUNT_ID") && config_env() != :test do
  config :o_grupo_de_estudos, OGrupoDeEstudos.Media.ObjectStorage,
    adapter: OGrupoDeEstudos.Media.ObjectStorage.R2

  config :o_grupo_de_estudos, OGrupoDeEstudos.Media.ObjectStorage.R2,
    account_id: System.fetch_env!("R2_ACCOUNT_ID"),
    access_key_id: System.fetch_env!("R2_ACCESS_KEY_ID"),
    secret_access_key: System.fetch_env!("R2_SECRET_ACCESS_KEY"),
    public_base_url: System.fetch_env!("R2_PUBLIC_BASE_URL"),
    private_bucket: System.get_env("R2_PRIVATE_BUCKET", "ogde-private"),
    public_bucket: System.get_env("R2_PUBLIC_BUCKET", "ogde-public")
end

# Google sign-in stays off (button hidden) until both credentials are set.
if config_env() != :test do
  if google_client_id = System.get_env("GOOGLE_OAUTH_CLIENT_ID") do
    config :o_grupo_de_estudos, :google_oauth,
      client_id: google_client_id,
      client_secret: System.fetch_env!("GOOGLE_OAUTH_CLIENT_SECRET")
  end
end

if config_env() == :prod do
  # Fly volume, mounted at /app/uploads (fly.toml). Explicit so it does not depend
  # on a File.dir? guessing the environment.
  config :o_grupo_de_estudos, :uploads_path, System.get_env("UPLOADS_PATH", "/app/uploads")

  config :o_grupo_de_estudos, OGrupoDeEstudos.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: System.get_env("SMTP_HOST", "smtp-relay.brevo.com"),
    port: String.to_integer(System.get_env("SMTP_PORT", "587")),
    username: System.get_env("SMTP_USERNAME"),
    password: System.get_env("SMTP_PASSWORD"),
    tls: :if_available,
    ssl: false

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :o_grupo_de_estudos, OGrupoDeEstudos.Repo,
    ssl: [verify: :verify_none],
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

  # Accept WebSocket connections from both the custom domain and the Fly.io
  # default hostname. Without this, Phoenix rejects the socket upgrade and
  # the client falls back to longpoll, which is dramatically slower and
  # causes infinite mount-retry loops on the custom domain.
  check_origins =
    ["https://#{host}"] ++
      Enum.map(
        String.split(System.get_env("PHX_EXTRA_HOSTS", ""), ",", trim: true),
        &"https://#{String.trim(&1)}"
      )

  config :o_grupo_de_estudos, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :o_grupo_de_estudos, OGrupoDeEstudosWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    check_origin: check_origins,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :o_grupo_de_estudos, OGrupoDeEstudosWeb.Endpoint,
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
  #     config :o_grupo_de_estudos, OGrupoDeEstudosWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
