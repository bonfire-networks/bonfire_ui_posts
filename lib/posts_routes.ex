defmodule Bonfire.UI.Posts.Routes do
  @behaviour Bonfire.UI.Common.RoutesModule

  defmacro __using__(_) do
    quote do
      # /post/:id — StaticGenerator caches the dead render for unauthenticated guests
      # (via the :browser_or_cacheable pipeline), but intentionally does NOT set
      # cache-control: public so CDN/browsers do not cache this response.
      # Full interactive browser stack runs for logged-in users.
      scope "/", Bonfire.UI.Posts do
        pipe_through(:browser_or_cacheable)

        live("/post/:id", PostLive, as: Bonfire.Data.Social.Post)
      end

      # /post_comments/:id — CDN-cacheable guest-only view.
      # Sets cache-control: public with long purgeable TTLs so CDN can cache it,
      # and MaybeStaticGeneratorPlug also writes it to the local static disk cache.
      pipeline :cacheable_post_public do
        plug(Bonfire.UI.Common.CacheControlPlug, purgeable: true)
      end

      scope "/", Bonfire.UI.Posts do
        pipe_through([:cacheable, :cacheable_post_public])

        live("/post_comments/:id", PostLive, as: :post_comments)
      end

      # Pages without StaticGenerator caching
      scope "/", Bonfire.UI.Posts do
        pipe_through(:browser)

        # live "/post", PostLive, as: Bonfire.Data.Social.Post

        live("/post/:id/reply/:reply_id", PostLive, as: Bonfire.Data.Social.Post)
        live("/post/:id/reply/:level/:reply_id", PostLive, as: Bonfire.Data.Social.Post)

        get("/post/markdown/:id", MarkdownPostController, :download_markdown)
      end

      # pages you need to view as a user
      scope "/", Bonfire.UI.Posts do
        pipe_through(:browser)
        pipe_through(:user_required)
      end

      # pages you need an account to view
      scope "/", Bonfire.UI.Posts do
        pipe_through(:browser)
        pipe_through(:account_required)
      end
    end
  end
end
