defmodule Bonfire.Social.Activities.CreatePost.Test do
  use Bonfire.UI.Posts.ConnCase, async: true
  use Bonfire.Common.Utils
  import Bonfire.Files.Simulation

  alias Bonfire.Social.Fake
  alias Bonfire.Posts
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Files.Test

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

    assert [ok] = find_flash(posted)
    {:ok, refreshed_view, _html} = live(conn, "/feed/local")
    # open_browser(refreshed_view)
  end

  describe "create a post" do
    test "shows a confirmation flash message" do
      some_account = fake_account!()
      someone = fake_user!(some_account)

      content = "here is an epic html post"

      conn = conn(user: someone, account: some_account)

      next = "/dashboard"
      {:ok, view, _html} = live(conn, next)
      # open_browser(view)

      # wait for persistent smart input to be ready
      live_async_wait(view)

      assert posted =
               view
               |> form("#smart_input form")
               |> render_submit(%{
                 "to_boundaries" => "public",
                 "post" => %{"post_content" => %{"html_body" => content}}
               })

      # |> Floki.text() =~ "Posted"

      # live_async_wait(view)
      # open_browser(view)
      # assert [ok] = find_flash(posted)
      assert has_element?(view, "[role=alert]", "Posted")
      # assert view |> Floki.text() =~ "Posted"
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
