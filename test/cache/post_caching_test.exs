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

  The disk backend permutation block runs the same suite for each supported
  disk cache backend: default (SimpleDiskCache fallback) and DiskLFUCache.

  These tests do NOT re-verify gen_avatar or memory-cache behaviour — see
  Bonfire.UI.Common.CacheControlPlugTest for those.
  """

  use Bonfire.UI.Posts.ConnCase, async: false

  alias Bonfire.Common.Types
  alias Bonfire.Common.Cache.DiskLFUCache
  alias Bonfire.Posts.Fake, as: PostFake
  alias Bonfire.UI.Common.MaybeStaticGeneratorPlug
  alias Bonfire.UI.Common.StaticGenerator
  alias Bonfire.UI.Common.Cache.HTTPPurge.StaticGenerator, as: PurgeAdapter

  setup do
    Process.put(
      [:bonfire_common, Bonfire.Common.Cache.HTTPPurge, :adapters],
      [PurgeAdapter]
    )

    Process.put(
      [:bonfire_ui_common, MaybeStaticGeneratorPlug, :sync_static_write],
      true
    )

    account = fake_account!()
    author = fake_user!(account)
    post = PostFake.fake_post!(author)
    post_id = Types.uid(post)

    dest = StaticGenerator.dest_path()
    on_exit(fn -> File.rm_rf!(Path.join([dest, "post", post_id])) end)

    {:ok, author: author, account: account, post_id: post_id, dest: dest}
  end

  disk_backend_permutations = [
    {nil, :disk_cache_backend, "default (SimpleDiskCache fallback)"},
    {DiskLFUCache, :disk_cache_backend, "DiskLFU as disk_cache_backend"},
    {DiskLFUCache, :cache_backend, "DiskLFU as sole cache_backend"}
  ]

  for {disk_backend, key, label} <- disk_backend_permutations do
    describe label do
      setup %{post_id: post_id} do
        root = Path.join(System.tmp_dir!(), "bonfire_test_#{:rand.uniform(1_000_000)}")
        File.mkdir_p!(root)
        {:ok, lfu_pid} = DiskLFUCache.start_link(root_path: root, max_bytes: nil)

        config =
          [root_path: root]
          |> then(fn c ->
            case unquote(disk_backend) do
              nil -> c
              b -> Keyword.put(c, unquote(key), b)
            end
          end)

        Process.put([:bonfire_ui_common, MaybeStaticGeneratorPlug], config)

        on_exit(fn ->
          GenServer.stop(lfu_pid)
          File.rm_rf!(root)
        end)

        {:ok, root: root, post_id: post_id}
      end

      test "unauthenticated GET writes the dead render to the static cache",
           %{post_id: post_id, root: root} do
        conn = get(build_conn(), "/post/#{post_id}")
        assert conn.status == 200

        assert File.exists?(Path.join([root, "post", post_id, "index.html"]))
      end

      test "second unauthenticated GET is served from the static disk cache",
           %{post_id: post_id, root: root} do
        first = get(build_conn(), "/post/#{post_id}")
        assert first.status == 200

        path = Path.join([root, "post", post_id, "index.html"])
        assert File.exists?(path), "expected first request to write the cached file at #{path}"

        File.write!(path, "CACHED_POST_SENTINEL")

        conn = get(build_conn(), "/post/#{post_id}")
        assert conn.status == 200
        assert conn.resp_body == "CACHED_POST_SENTINEL"
      end

      test "authenticated GET is NOT written to the static cache",
           %{author: author, account: account, post_id: post_id, root: root} do
        authed_conn = conn(user: author, account: account)
        conn = get(authed_conn, "/post/#{post_id}")
        assert conn.status == 200

        refute File.exists?(Path.join([root, "post", post_id, "index.html"]))
      end
    end
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
