defmodule Bonfire.UI.Posts.PostReplyLinkTest do
  @moduledoc """
  The post page opened with a reply link (`/post/:id/reply/:level/:reply_id`, see `posts_routes.ex`), which passes `include_path_ids` to the thread.
  """
  use Bonfire.UI.Posts.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.Posts

  defp publish(user, reply_to_id, body) do
    {:ok, post} =
      Posts.publish(
        current_user: user,
        post_attrs: %{post_content: %{html_body: body}, reply_to_id: reply_to_id},
        boundary: "public"
      )

    post
  end

  defp chain(user, root, count, body),
    do: Enum.scan(1..count, root, fn n, parent -> publish(user, parent.id, "#{body} #{n}") end)

  test "shows the visible deep reply, and not another thread's reply named in the link" do
    alice = fake_user!()
    bob = fake_user!()

    post = publish(alice, nil, "post page original")
    deep = post |> then(&chain(alice, &1, 5, "post page deep reply")) |> List.last()

    other_op = publish(alice, nil, "post page other thread")
    other = other_op |> then(&chain(alice, &1, 5, "post page other reply")) |> List.last()

    conn = conn(user: bob, account: bob.account)

    main_text = fn path ->
      {:ok, view, _html} = live(conn, path)

      view
      |> render_async()
      |> Floki.parse_document!()
      |> Floki.find("[data-id=main_section]")
      |> Floki.text()
    end

    assert main_text.("/post/#{post.id}/reply/6/#{deep.id}") =~ "post page deep reply 5"

    refute main_text.("/post/#{post.id}/reply/6/#{other.id}") =~ "post page other reply"
  end
end
