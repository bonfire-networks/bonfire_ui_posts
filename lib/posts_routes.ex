defmodule Bonfire.UI.Posts.Routes do
  @behaviour Bonfire.UI.Common.RoutesModule

  defmacro __using__(_) do
    quote do
      # pages anyone can view
      scope "/", Bonfire.UI.Posts do
        pipe_through(:browser)

        # live "/post", PostLive, as: Bonfire.Data.Social.Post
        live("/post/:id", PostLive, as: Bonfire.Data.Social.Post)
        live("/post/:id/reply/:reply_id", PostLive, as: Bonfire.Data.Social.Post)
        live("/post/:id/reply/:level/:reply_id", PostLive, as: Bonfire.Data.Social.Post)

        get "/post/markdown/:id", MarkdownPostController, :download_markdown
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
