import Config

config :bonfire_common,
  otp_app: :bonfire_ui_posts

config :bonfire_ui_posts,
  otp_app: :bonfire_ui_posts

# Choose password hashing backend
# Note that this corresponds with our dependencies in mix.exs
hasher = if config_env() in [:dev, :test], do: Pbkdf2, else: Argon2
config :bonfire_data_identity, Bonfire.Data.Identity.Credential, hasher_module: hasher

# include all used Bonfire extensions
import_config "bonfire_ui_posts.exs"

#### Basic configuration

# You probably won't want to touch these. You might override some in
# other config files.

config :bonfire, :repo_module, Bonfire.Common.Repo

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :mime, :types, %{
  "application/activity+json" => ["activity+json"]
}

# import_config "#{Mix.env()}.exs"
