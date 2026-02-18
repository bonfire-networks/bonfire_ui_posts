defmodule Bonfire.UI.Posts.PostCachingTest do
  @moduledoc """
  Focused tests for caching behaviour on post routes.

  `/post/:id` — StaticGenerator-only caching (no CDN headers):
  - Unauthenticated dead renders are written to the static cache on the first miss.
  - Subsequent unauthenticated requests are served from the static disk cache.
  - Authenticated requests are never written to the static cache.

  `/post_comments/:id` — CDN-cacheable guest-only route:
  - Sets cache-control: public with max-age, s-maxage, stale-while-revalidate.
  - Does not emit Set-Cookie.

  These tests do NOT re-verify gen_avatar or memory-cache behaviour — see
  Bonfire.UI.Common.CacheControlPlugTest for those.
  """

  use Bonfire.UI.Posts.ConnCase, async: false

  alias Bonfire.Common.Types
  alias Bonfire.Posts.Fake, as: PostFake
  alias Bonfire.UI.Common.StaticGenerator
  alias Bonfire.UI.Common.Cache.HTTPPurge.StaticGenerator, as: PurgeAdapter

  setup do
    # Activate the StaticGenerator purge adapter so MaybeStaticGeneratorPlug's
    # before_send hook writes each unauthenticated response to disk.
    Process.put(
      [:bonfire_common, Bonfire.Common.Cache.HTTPPurge, :adapters],
      [PurgeAdapter]
    )

    account = fake_account!()
    author = fake_user!(account)
    post = PostFake.fake_post!(author)
    post_id = Types.uid(post)

    dest = StaticGenerator.dest_path()
    on_exit(fn -> File.rm_rf!(Path.join([dest, "post", post_id])) end)

    {:ok, author: author, account: account, post_id: post_id, dest: dest}
  end

  test "unauthenticated GET writes the dead render to the static cache", %{
    post_id: post_id,
    dest: dest
  } do
    conn = get(build_conn(), "/post/#{post_id}")
    assert conn.status == 200

    assert File.exists?(Path.join([dest, "post", post_id, "index.html"]))
  end

  test "second unauthenticated GET is served from the static disk cache", %{
    post_id: post_id,
    dest: dest
  } do
    # First visit — controller renders, writes to cache
    first = get(build_conn(), "/post/#{post_id}")
    assert first.status == 200

    path = Path.join([dest, "post", post_id, "index.html"])
    assert File.exists?(path), "expected first request to write the cached file at #{path}"

    # Replace with sentinel to confirm the next hit comes from disk, not the controller
    File.write!(path, "CACHED_POST_SENTINEL")

    conn = get(build_conn(), "/post/#{post_id}")
    assert conn.status == 200
    assert conn.resp_body == "CACHED_POST_SENTINEL"
  end

  test "authenticated GET is NOT written to the static cache", %{
    author: author,
    account: account,
    post_id: post_id,
    dest: dest
  } do
    authed_conn = conn(user: author, account: account)
    conn = get(authed_conn, "/post/#{post_id}")
    assert conn.status == 200

    refute File.exists?(Path.join([dest, "post", post_id, "index.html"]))
  end

  describe "/post_comments/:id (CDN-cacheable guest route)" do
    test "sets cache-control: public with CDN TTLs", %{post_id: post_id} do
      conn = get(build_conn(), "/post_comments/#{post_id}")
      assert conn.status == 200

      assert [cache_control] = get_resp_header(conn, "cache-control")
      assert cache_control =~ "public"
      assert cache_control =~ "max-age="
      assert cache_control =~ "s-maxage="
      assert cache_control =~ "stale-while-revalidate="
    end

    test "does not emit Set-Cookie", %{post_id: post_id} do
      conn = get(build_conn(), "/post_comments/#{post_id}")
      assert get_resp_header(conn, "set-cookie") == []
    end
  end
end
