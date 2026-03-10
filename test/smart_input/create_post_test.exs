defmodule Bonfire.UI.Posts.CreatePostTest do
  use Bonfire.UI.Posts.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  use Bonfire.Common.Utils
  import Bonfire.Files.Simulation

  alias Bonfire.Social.Fake
  alias Bonfire.Posts
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Files.Test

  defp submit_post(session, content) do
    session
    |> PhoenixTest.unwrap(fn view ->
      view
      |> Phoenix.LiveViewTest.element("#smart_input_form")
      |> Phoenix.LiveViewTest.render_submit(%{
        "post" => %{"post_content" => %{"html_body" => content}}
      })
    end)
  end

  describe "create a post" do
    test "works" do
      some_account = fake_account!()
      someone = fake_user!(some_account)
      content = "here is an epic html post"

      conn = conn(user: someone, account: some_account)

      conn
      |> visit("/feed/local")
      |> submit_post(content)
      |> wait_async()
      |> assert_has_or_open_browser("[data-id=feed] article", text: content)
    end

    test "shows up on my profile timeline" do
      some_account = fake_account!()
      someone = fake_user!(some_account)
      content = "here is an epic html post"

      conn = conn(user: someone, account: some_account)

      conn
      |> visit("/feed/local")
      |> submit_post(content)
      |> wait_async()
      |> visit("/user")
      |> assert_has_or_open_browser("[data-id=feed] article", text: content)
    end

    test "shows up in feed right away" do
      some_account = fake_account!()
      someone = fake_user!(some_account)
      content = "here is a post to test pubsub"

      conn = conn(user: someone, account: some_account)

      conn
      |> visit("/feed")
      |> submit_post(content)
      |> wait_async()
      |> assert_has_or_open_browser("[data-id=feed]", text: content)
    end

    test "i can reply in feed right away" do
      some_account = fake_account!()
      someone = fake_user!(some_account)
      alice = fake_user!(some_account)
      content = "epic post!"

      attrs = %{
        post_content: %{summary: "summary", html_body: content}
      }

      {:ok, _post} = Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      content_reply = "epic reply!"
      conn = conn(user: alice, account: some_account)

      conn
      |> visit("/feed")
      |> assert_has("[data-id=feed] article", text: content)
      |> submit_post(content_reply)
      |> wait_async()
      |> assert_has_or_open_browser("[data-id=feed] article", text: content_reply)
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

      bob_conn
      |> visit("/post/#{id(op)}")
      |> click_link("Reply")
      |> submit_post(content)

      alice_conn = conn(user: alice)

      alice_conn
      |> visit("/@#{bob.character.username}")
      |> assert_has("[data-id=feed] article", text: content)
    end
  end
end
