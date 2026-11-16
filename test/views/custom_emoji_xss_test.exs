defmodule Bonfire.UI.Posts.CustomEmojiXSSTest do
  @moduledoc """
  A word in a post that looks like `:family:icon:` becomes an emoji image. Whatever the author types in that word is data: it can never add an attribute to the image or leave the `src` it is placed in.
  """
  use Bonfire.UI.Posts.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  alias Bonfire.Posts

  defp publish(user, body) do
    {:ok, post} =
      Posts.publish(
        current_user: user,
        post_attrs: %{post_content: %{html_body: body}},
        boundary: "public"
      )

    post
  end

  setup do
    account = fake_account!()
    me = fake_user!(account)
    %{me: me, conn: conn(user: me, account: account)}
  end

  test "control: a normal icon word renders as an image with the matching src", %{
    me: me,
    conn: conn
  } do
    post = publish(me, "hi :mdi:home: there")

    conn
    |> visit("/post/#{post.id}")
    |> wait_async()
    |> assert_has("[data-id=main_section] img[src='https://api.iconify.design/mdi/home.svg']")
  end

  test "a word with a quote in its icon family does not add an event handler attribute", %{
    me: me,
    conn: conn
  } do
    post = publish(me, "hi :x'onerror='alert(1):y: there")

    # the stored body has no quote that ends the `src`
    body = Bonfire.Common.Config.repo().preload(post, :post_content).post_content.html_body
    refute body =~ "'onerror='", "stored body: #{inspect(body)}"

    conn
    |> visit("/post/#{post.id}")
    |> wait_async()
    # the post itself is shown
    |> assert_has("[data-id=main_section]", text: "hi")
    # no image got an attribute out of the quoted `src`
    |> refute_has("[data-id=main_section] [onerror*='alert(1)']")
  end
end
