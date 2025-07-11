defmodule Bonfire.UI.Posts.RuntimeConfig do
  use Bonfire.Common.Localise

  @behaviour Bonfire.Common.ConfigModule
  def config_module, do: true

  @doc """
  NOTE: you can override this default config in your app's `runtime.exs`, by placing similarly-named config keys below the `Bonfire.Common.Config.LoadExtensionsConfig.load_configs()` line
  """
  def config do
    import Config

    # config :bonfire_ui_social,
    #   modularity: :disabled

    config :bonfire, :ui,
      explore: [
        sections: [
          posts: Bonfire.UI.Social.FeedsLive
        ],
        navigation: [
          posts: l("Posts")
        ]
      ],
      profile: [
        sections: [
          # posts: Bonfire.UI.Posts.ProfilePostsLive
        ],
        navigation: [
          # posts: l("Posts")
        ],
        widgets: []
      ]
  end
end
