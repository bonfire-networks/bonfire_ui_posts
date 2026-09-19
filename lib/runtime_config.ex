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

    # One getting-started step, declared here because writing a post is this extension's feature. The widget that shows it holds no steps of its own, and this list merges with what every other extension declares. The copy is compiled here so `mix gettext.extract` sees it, and the detector is a function below.
    config :bonfire_ui_common, Bonfire.UI.Common.WidgetGettingStartedLive,
      actions_registry: [
        first_post: %{
          title: l("Write your first post"),
          rationale: l("Your voice is what makes the feed worth coming back to."),
          cta_label: l("Compose a post"),
          cta_kind: :composer,
          cta_path: nil,
          needs: Bonfire.Posts,
          done?: &Bonfire.Posts.any_by?/1
        }
      ]

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

    # Posts: optional title (toggle) and content-warning siren. `nil` covers the
    # default/reply composer (which is a post).
    config :bonfire_ui_common, Bonfire.UI.Common.InputControlsLive,
      enable_fields: [
        title: [post: [enable_toggle: true]],
        sensitive: [{nil, [enable_toggle: true]}, {:post, [enable_toggle: true]}]
      ]
  end
end
