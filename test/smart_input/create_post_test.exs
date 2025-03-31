defmodule Bonfire.Social.Activities.CreatePost.Test do
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

    # login as alice
    conn = conn(user: alice, account: account)
    {:ok, view, _html} = live(conn, "/write")
    # view = Phoenix.LiveViewTest.allow_upload(view, :files, accept: :any, max_entries: 10)
    file = Path.expand("../fixtures/icon.png", __DIR__)
    # open_browser(view)

    icon =
      file_input(view, "#smart_input_form", :files, [
        %{
          name: "image.png",
          content: File.read!(file),
          type: "image/png"
        }
      ])

    uploaded = render_upload(icon, "image.png")

    # create a post
    content = "here is an epic html post"

    assert posted =
             view
             |> form("#smart_input_form")
             |> render_submit(%{
               "to_boundaries" => "public",
               "post" => %{"post_content" => %{"html_body" => content}}
             })

    # assert [ok] = find_flash(posted)
    {:ok, refreshed_view, _html} = live(conn, "/feed/local")

    Phoenix.LiveViewTest.open_browser(refreshed_view)
  end

  describe "create a post" do
    test "works" do
      some_account = fake_account!()
      someone = fake_user!(some_account)

      content = "here is an epic html post"

      conn = conn(user: someone, account: some_account)

      next = "/feed/local"
      {:ok, view, _html} = live(conn, next)
      assert posted =
               view
               |> form("#smart_input form")
               |> render_submit(%{
                 "to_boundaries" => "public",
                 "post" => %{"post_content" => %{"html_body" => content}}
               })

      assert has_element?(view, "[data-id=feed]", content)
    end

    test "shows up on my profile timeline" do
      some_account = fake_account!()
      someone = fake_user!(some_account)

      content = "here is an epic html post"

      conn = conn(user: someone, account: some_account)

      next = "/settings"
      # |> IO.inspect
      {:ok, view, _html} = live(conn, next)
      # open_browser(view)
      live_async_wait(view)

      assert posted =
               view
               |> form("#smart_input form")
               |> render_submit(%{
                 "to_boundaries" => "public",
                 "post" => %{"post_content" => %{"html_body" => content}}
               })

      next = "/user"
      # |> IO.inspect
      {:ok, profile, _html} = live(conn, next)
      assert has_element?(profile, "[data-id=feed]", content)
    end

    test "shows up in feed right away" do
      some_account = fake_account!()
      someone = fake_user!(some_account)

      content = "here is a post to test pubsub"

      conn = conn(user: someone, account: some_account)

      next = "/feed"
      # |> IO.inspect
      {:ok, view, _html} = live(conn, next)

      assert view
             |> form("#smart_input form")
             |> render_submit(%{
               "to_boundaries" => "public",
               "post" => %{"post_content" => %{"html_body" => content}}
             })

      # check if post appears instantly on home feed (with pubsub)
      live_async_wait(view)

      assert has_element?(view, "[data-id=feed]", content)
    end


    test "i can reply in feed right away" do
      some_account = fake_account!()
      someone = fake_user!(some_account)
      alice = fake_user!(some_account)

      content = "epic post!"
      attrs = %{
        post_content: %{summary: "summary", name: "name 2", html_body: content},
        }

      assert {:ok, post} =
        Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      content_reply = "epic reply!"
      conn = conn(user: alice, account: some_account)
      next = "/feed"
      # |> IO.inspect
      {:ok, alice_view, _html} = live(conn, next)
      # Phoenix.LiveViewTest.open_browser(alice_view)
      assert has_element?(alice_view, "[data-id=feed]", content)
      assert alice_view
             |> form("#smart_input form")
             |> render_submit(%{
               "to_boundaries" => "public",
               "post" => %{
                "post_content" => %{"html_body" => content_reply},
                "reply_to_id" =>  post.id
              }
             })
      assert has_element?(alice_view, "[data-id=feed]", content_reply)
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

      assert {:ok, op} =
               Posts.publish(current_user: alice, post_attrs: attrs, boundary: "mentions")

      content = "here is an epic html post"

      conn = conn(user: bob)

      next = "/post/#{id(op)}"
      # |> IO.inspect
      {:ok, view, _html} = live(conn, next)
      live_async_wait(view)

      assert _click =
               view
               |> element("[data-id=action_reply]")
               |> render_click()

      # open_browser(view)

      assert view
             |> form("#smart_input form")
             |> render_submit(%{
               "to_boundaries" => "mentions",
               "post" => %{"post_content" => %{"html_body" => content}}
             })

      conn2 = conn(user: alice)

      next = "/@#{bob.character.username}"
      # |> IO.inspect
      {:ok, feed, _html} = live(conn2, next)
      assert has_element?(feed, "[data-id=feed]", content)

      # WIP: does this test do what's expected?
    end
  end
end
