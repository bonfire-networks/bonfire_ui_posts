defmodule Bonfire.UI.Posts.ComposerAudienceEndToEndTest do
  @moduledoc """
  The composer's audience choices, made through its own controls and sent by its own form, give the published post the permissions the person chose. The other tests stop at the form's hidden fields (composer tests) or build the submitted params by hand (`ComposerPerActionTogglesTest`); these cover the step in between.
  """
  use Bonfire.UI.Posts.ConnCase, async: false
  @moduletag :ui

  import Ecto.Query
  alias Bonfire.UI.Common.Testing.Helpers, as: ComposerHelpers
  alias Bonfire.Boundaries

  # the post just published, found by its unique text, since submitting the form does not hand it back
  defp published!(text) do
    id =
      Bonfire.Common.Config.repo().one!(
        from(pc in Bonfire.Data.Social.PostContent,
          where: ilike(pc.html_body, ^"%#{text}%"),
          select: pc.id
        )
      )

    {:ok, post} = Bonfire.Posts.read(id, skip_boundary_check: true)
    post
  end

  test "a post to a circle, picked in the visibility menu, is read by its members and no one else" do
    account = fake_account!()
    author = fake_user!(account)
    member = fake_user!()
    outsider = fake_user!()
    {:ok, circle} = Boundaries.Circles.create(author, "Book club")
    {:ok, _} = Boundaries.Circles.add_to_circles(member, circle)
    text = "for the book club #{System.unique_integer([:positive])}"

    conn(user: author, account: account)
    |> visit("/feed/local")
    |> PhoenixTest.unwrap(fn view ->
      composer = ComposerHelpers.composer_view(view)
      ComposerHelpers.open_menu(composer, "composer_visibility_picker")
      composer |> element("[data-audience-circle='#{circle.id}']") |> render_click()
      ComposerHelpers.submit_composer(view, text, %{})
    end)

    post = published!(text)
    assert Boundaries.can?(member, :read, post), "a member of the circle reads it"
    refute Boundaries.can?(outsider, :read, post), "someone outside the circle doesn't"
    refute Boundaries.can?(:guest, :read, post), "a guest doesn't"
  end

  test "Allow replies? off in Custom boundaries: others read the post but can't reply" do
    account = fake_account!()
    author = fake_user!(account)
    other = fake_user!()
    text = "no replies please #{System.unique_integer([:positive])}"

    conn(user: author, account: account)
    |> visit("/feed/local")
    |> PhoenixTest.unwrap(fn view ->
      composer = ComposerHelpers.composer_view(view)
      composer |> element("#define_permissions button[data-role=open_modal]") |> render_click()

      composer
      |> element("#customize_boundary_live [data-role=action_toggle_reply]")
      |> render_click()

      composer |> element("#customize_boundary_live [data-role=save_boundary]") |> render_click()
      ComposerHelpers.submit_composer(view, text, %{})
    end)

    post = published!(text)
    assert Boundaries.can?(other, :read, post), "others still read it"
    refute Boundaries.can?(other, :reply, post), "but can't reply"
  end
end
