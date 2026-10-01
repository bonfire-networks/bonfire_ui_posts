defmodule Bonfire.UI.Posts.ComposerPerActionTogglesTest do
  @moduledoc """
  What the composer's per-action toggles ("Allow reading?", "Allow replies?", "Allow quotes?", and their exception circles) do to the post they publish.

  The toggles' `verb_permissions` are built by the product's own toggle code (`CustomizeBoundaryLive.apply_action_toggle/4`, and `VerbGrants.update_verb_permission/4` for an exception circle), then published through the composer's submit (`PostsLiveHandler.publish_post/2`), so the outcome is what a person toggling them would get.
  """
  use Bonfire.UI.Posts.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Boundaries
  alias Bonfire.UI.Boundaries.CustomizeBoundaryLive
  alias Bonfire.UI.Boundaries.PerActionDefaultsLive
  alias Bonfire.Posts.LiveHandler, as: PostsLiveHandler

  @preset {"public", "Public"}

  defp verbs_of(action_key),
    do: Enum.find(PerActionDefaultsLive.actions(), &(&1.key == action_key)).verbs

  # the toggle switched on or off, as the composer does
  defp toggle(verb_permissions \\ %{}, action_key, allowed?) do
    {updated, _grants} =
      CustomizeBoundaryLive.apply_action_toggle(allowed?, @preset, verbs_of(action_key), verb_permissions)

    updated
  end

  # an exception circle ticked under an action, as the composer does
  defp except(verb_permissions, action_key, circle_id) do
    Enum.reduce(verbs_of(action_key), verb_permissions, fn verb, acc ->
      Bonfire.Boundaries.VerbGrants.update_verb_permission(acc, circle_id, verb, :can)
    end)
  end

  defp publish!(author, verb_permissions) do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, current_user: author, __context__: %{current_user: author}}
    }

    {:ok, post} =
      PostsLiveHandler.publish_post(
        %{
          "post" => %{"post_content" => %{"html_body" => "a post"}},
          "to_boundaries" => ["public"],
          "verb_permissions" => verb_permissions
        },
        socket
      )

    post
  end

  test "Allow replies? off: others still read it, but can't reply" do
    author = fake_user!()
    other = fake_user!()
    assert Boundaries.can?(other, :reply, publish!(author, %{})), "control: by default they may"

    post = publish!(author, toggle("reply", false))
    assert Boundaries.can?(other, :read, post)
    refute Boundaries.can?(other, :reply, post)
  end

  test "Allow reading? off: others can't read it" do
    author = fake_user!()
    other = fake_user!()
    assert Boundaries.can?(other, :read, publish!(author, %{})), "control: by default they may"

    refute Boundaries.can?(other, :read, publish!(author, toggle("read", false)))
  end

  test "Allow quotes? on: others may quote it" do
    author = fake_user!()
    other = fake_user!()
    refute Boundaries.can?(other, :quote, publish!(author, %{})), "control: by default they may not"

    assert Boundaries.can?(other, :quote, publish!(author, toggle("quote", true)))
  end

  # an exception is granted the action instead of everyone being denied it (a denial always wins, so it can't be undone for some): the post gets the preset's grants without the action, plus the action for the ticked circles
  test "Public, Allow reading? off, People I am following ticked: someone I follow reads it, someone else doesn't" do
    author = fake_user!()
    followed = fake_user!()
    other = fake_user!()
    {:ok, _} = Bonfire.Social.Graph.Follows.follow(author, followed)

    [following] = Bonfire.Boundaries.Circles.get_stereotype_circles(author, [:followed])

    post = publish!(author, toggle("read", false) |> except("read", following.id))
    assert Boundaries.can?(followed, :read, post), "someone I follow reads it"
    refute Boundaries.can?(other, :read, post), "someone else doesn't"
    refute Boundaries.can?(:guest, :read, post), "a guest doesn't"
  end

  test "control: Allow reading? off with no exceptions still keeps everyone else out" do
    author = fake_user!()
    other = fake_user!()

    post = publish!(author, toggle("read", false))
    refute Boundaries.can?(other, :read, post)
    refute Boundaries.can?(:guest, :read, post)
  end

  test "Allow replies? off with an exception circle: its members may still reply, others not" do
    author = fake_user!()
    friend = fake_user!()
    other = fake_user!()
    {:ok, circle} = Bonfire.Boundaries.Circles.create(author, %{named: %{name: "friends"}})
    {:ok, _} = Bonfire.Boundaries.Circles.add_to_circles(friend, circle)

    post = publish!(author, toggle("reply", false) |> except("reply", circle.id))
    assert Boundaries.can?(friend, :reply, post), "a member of the exception circle may"
    refute Boundaries.can?(other, :reply, post), "someone else may not"
  end
end
