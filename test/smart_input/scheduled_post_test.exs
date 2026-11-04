defmodule Bonfire.UI.Posts.ScheduledPostTest do
  use Bonfire.UI.Posts.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  import Ecto.Query

  setup do
    account = fake_account!()
    me = fake_user!(account)

    {:ok, conn: conn(user: me, account: account), me: me}
  end

  # A `datetime-local` value has no offset, so the browser converts it to UTC into a hidden field and only that field is submitted
  test "the composer submits the scheduled time as a hidden UTC field", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/feed/local")
    composer = composer_view(view)

    assert has_element?(composer, "#smart_input_scheduled_at input[type=datetime-local]")

    assert has_element?(
             composer,
             "#smart_input_scheduled_at input[type=hidden][name=scheduled_at]"
           )

    refute has_element?(composer, "#smart_input_scheduled_at input[type=datetime-local][name]")
  end

  test "a post scheduled from the composer stays out of the feed until its time", %{conn: conn} do
    unique = System.unique_integer([:positive])
    visible_content = "visible now #{unique}"
    scheduled_content = "scheduled later #{unique}"

    scheduled_dt =
      DateTime.utc_now()
      |> DateTime.add(7, :day)
      |> Map.merge(%{second: 0, microsecond: {0, 0}})

    # The shape `new Date(value).toISOString()` gives in the browser
    scheduled_value = Calendar.strftime(scheduled_dt, "%Y-%m-%dT%H:%M:%S.000Z")

    conn
    |> visit("/feed/local")
    |> submit_composer(visible_content)
    |> wait_async()
    |> assert_has_or_open_browser("[data-id=feed] article", text: visible_content)
    |> submit_composer(scheduled_content, %{"scheduled_at" => scheduled_value})
    |> wait_async()
    |> refute_has("[data-id=feed] article", text: scheduled_content)

    scheduled_post =
      Bonfire.Common.Repo.one!(
        from pc in Bonfire.Data.Social.PostContent,
          where: ilike(pc.html_body, ^"%#{scheduled_content}%")
      )

    {:ok, ulid_ts} = Needle.ULID.timestamp(scheduled_post.id)
    assert ulid_ts == DateTime.to_unix(scheduled_dt, :millisecond)
  end
end
