defmodule Bonfire.UI.Posts.CreatePostTest do
  use Bonfire.UI.Posts.ConnCase, async: true
  use Bonfire.Common.Utils
  import Bonfire.Files.Simulation

  alias Bonfire.Social.Fake
  alias Bonfire.Posts
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Files.Test

  @tag :todo
  test "create a post with uploads" do
    # Create alice user
    account = fake_account!()
    alice = fake_user!(account)

    conn = conn(user: alice, account: account)

    conn
    |> visit("/write")
    |> fill_in("#editor_hidden_input", "Content", with: "here is an epic html post")
    |> upload("files", "test/fixtures/icon.png")
    |> click_button("Publish")
    |> visit("/feed/local")
    |> assert_has("[data-id=feed] article", text: "here is an epic html post")
  end

  describe "create a post" do
    test "works" do
      some_account = fake_account!()
      someone = fake_user!(some_account)
      content = "here is an epic html post"

      conn = conn(user: someone, account: some_account)

      conn
      |> visit("/feed/local")
      |> fill_in("#editor_hidden_input", "Content", with: content)
      |> click_button("Publish")
      |> wait_async()
      |> assert_has_or_open_browser("[data-id=feed] article", text: content)
    end

    test "shows up on my profile timeline" do
      some_account = fake_account!()
      someone = fake_user!(some_account)
      content = "here is an epic html post"

      conn = conn(user: someone, account: some_account)

      conn
      |> visit("/settings")
      |> fill_in("#editor_hidden_input", "Content", with: content)
      |> click_button("Publish")
      |> visit("/user")
      |> assert_has("[data-id=feed] article", text: content)
    end

    test "shows up in feed right away" do
      some_account = fake_account!()
      someone = fake_user!(some_account)
      content = "here is a post to test pubsub"

      conn = conn(user: someone, account: some_account)

      conn
      |> visit("/feed")
      |> fill_in("#editor_hidden_input", "Content", with: content)
      |> click_button("Publish")
      |> wait_async()
      |> assert_has_or_open_browser("[data-id=feed]", text: content)
    end

    test "i can reply in feed right away" do
      some_account = fake_account!()
      someone = fake_user!(some_account)
      alice = fake_user!(some_account)
      content = "epic post!"

      attrs = %{
        post_content: %{summary: "summary", name: "name 2", html_body: content}
      }

      {:ok, post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      content_reply = "epic reply!"
      conn = conn(user: alice, account: some_account)

      conn
      |> visit("/feed")
      |> assert_has("#feed_my article", text: content)
      |> fill_in("#editor_hidden_input", "Content", with: content_reply)
      |> click_button("Publish")
      |> wait_async()
      |> assert_has_or_open_browser("#feed_my article", text: content_reply)
    end

    @tag :todo
    test "has the correct permissions when replying" do
      alice = fake_user!("none")
      bob = fake_user!("contribute")

      attrs = %{
        post_content: %{
          summary: "summary",
          name: "test post name",
          html_body: "@#{bob.character.username} first post</p>"
        }
      }

      {:ok, op} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "mentions")

      content = "here is an epic html post"
      bob_conn = conn(user: bob)

      bob_conn
      |> visit("/post/#{id(op)}")
      |> click_link("Reply")
      |> fill_in("#editor_hidden_input", "Content", with: content)
      |> click_button("Publish")

      alice_conn = conn(user: alice)

      alice_conn
      |> visit("/@#{bob.character.username}")
      |> assert_has("[data-id=feed] article", text: content)
    end
  end
end
