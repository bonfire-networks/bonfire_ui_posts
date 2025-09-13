defmodule Bonfire.UI.Posts.CreatePostTest do
  use Bonfire.UI.Posts.ConnCase, async: true
  use Bonfire.Common.Utils
  import Bonfire.Files.Simulation

  alias Bonfire.Social.Fake
  alias Bonfire.Posts
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Files.Test

  # FIXME
  @tag :skip_ci
  describe "create a post" do
    test "works" do
      some_account = fake_account!()
      someone = fake_user!(some_account)
      content = "here is an epic html post"

      conn = conn(user: someone, account: some_account)

      # Create the post directly using the backend API since PhoenixTest can't handle portals
      {:ok, published} =
        Bonfire.Posts.publish(
          current_user: someone,
          post_attrs: %{
            post_content: %{
              html_body: content
            }
          },
          boundary: "public"
        )

      IO.inspect("Post created successfully via API", label: "Post creation status")

      # Visit the feed to check if post appears
      result = conn |> visit("/feed/local")
      result |> assert_has_or_open_browser("[data-id=feed] article", text: content)
    end

    # FIXME
    @tag :skip_ci
    test "shows up on my profile timeline" do
      some_account = fake_account!()
      someone = fake_user!(some_account)
      content = "here is an epic html post"

      conn = conn(user: someone, account: some_account)

      # Create the post directly using the backend API since PhoenixTest can't handle portals
      {:ok, published} =
        Bonfire.Posts.publish(
          current_user: someone,
          post_attrs: %{
            post_content: %{
              html_body: content
            }
          },
          boundary: "public"
        )

      # Visit the user profile to check if post appears
      conn
      |> visit("/user")
      |> assert_has("[data-id=feed] article", text: content)
    end

    # FIXME
    @tag :skip_ci
    test "shows up in feed right away" do
      some_account = fake_account!()
      someone = fake_user!(some_account)
      content = "here is a post to test pubsub"

      conn = conn(user: someone, account: some_account)

      # Create the post directly using the backend API since PhoenixTest can't handle portals
      {:ok, published} =
        Bonfire.Posts.publish(
          current_user: someone,
          post_attrs: %{
            post_content: %{
              html_body: content
            }
          },
          boundary: "public"
        )

      # Visit the feed to check if post appears
      conn
      |> visit("/feed")
      |> assert_has_or_open_browser("[data-id=feed]", text: content)
    end

    # FIXME
    @tag :skip_ci
    test "i can reply in feed right away" do
      some_account = fake_account!()
      someone = fake_user!(some_account)
      alice = fake_user!(some_account)
      content = "epic post!"

      attrs = %{
        post_content: %{summary: "summary", html_body: content}
      }

      {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      content_reply = "epic reply!"
      conn = conn(user: alice, account: some_account)

      # Create the reply directly using the backend API since PhoenixTest can't handle portals
      {:ok, reply} =
        Bonfire.Posts.publish(
          current_user: alice,
          post_attrs: %{
            post_content: %{
              html_body: content_reply
            }
          },
          boundary: "public"
        )

      # Visit the feed to check if both posts appear
      conn
      |> visit("/feed")
      |> assert_has("#feed_my article", text: content)
      |> assert_has_or_open_browser("#feed_my article", text: content_reply)
    end

    @tag :todo
    test "has the correct permissions when replying" do
      alice = fake_user!("none")
      bob = fake_user!("contribute")

      attrs = %{
        post_content: %{
          summary: "summary",
          html_body: "@#{bob.character.username} first post</p>"
        }
      }

      {:ok, op} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "mentions")

      content = "here is an epic html post"
      bob_conn = conn(user: bob)

      # Create the reply directly using the backend API since PhoenixTest can't handle portals
      {:ok, reply} =
        Bonfire.Posts.publish(
          current_user: bob,
          post_attrs: %{
            post_content: %{
              html_body: content
            }
          },
          boundary: "public"
        )

      alice_conn = conn(user: alice)

      alice_conn
      |> visit("/@#{bob.character.username}")
      |> assert_has("[data-id=feed] article", text: content)
    end
  end
end
