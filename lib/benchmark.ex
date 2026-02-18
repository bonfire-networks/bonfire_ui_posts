defmodule Bonfire.UI.Posts.Benchmark do
  @moduledoc """
  Benchmarks for the different ways a post page and its comments can be served.

  Run from iex (make sure you have seed data or call `setup_posts/0` first):

      Bonfire.UI.Posts.Benchmark.post_page()

  The scenarios compared:

  - `:browser` pipeline — full render for an authenticated user (no cache)
  - `:browser_or_cacheable`, dead render uncached — unauthenticated with ?cache=skip
  - `:browser_or_cacheable`, cache miss — first unauthenticated request,
    LiveView dead render, writes to the StaticGenerator disk cache
  - `:browser_or_cacheable`, disk cache hit — subsequent unauthenticated
    request served by Plug.Static from `priv/static/public`
  - `:browser_or_cacheable`, memory cache hit — same URL after being promoted
    to Cachex by MaybeStaticGeneratorPlug (threshold must be set)

  Each scenario is run for every input (post with N comments).

  # TODO with CDN:
  - `/post_comments/:id` (CDN-cacheable), cache miss — first unauthenticated
    request through `:cacheable` + `CacheControlPlug`
  - `/post_comments/:id`, disk cache hit — served from static disk cache
  """

  @endpoint Bonfire.Web.Endpoint
  import Phoenix.ConnTest
  import Bonfire.UI.Common.Testing.Helpers
  use Bonfire.Common.Config
  alias Bonfire.Common.Utils
  import Untangle

  alias Bonfire.Common.Cache
  alias Bonfire.Posts.Fake, as: PostFake
  alias Bonfire.Common.Types
  alias Bonfire.UI.Common.StaticGenerator
  alias Bonfire.UI.Common.MaybeStaticGeneratorPlug
  alias Bonfire.UI.Common.Cache.HTTPPurge.StaticGenerator, as: PurgeAdapter

  @log_level :info

  # NOTE: make sure you have a running instance with seed data, or call setup_posts/0 first.

  @doc """
  Creates one post per comment count and returns `{user, account, inputs_map}` where
  `inputs_map` is `%{"N comments" => post_id}` suitable for passing to Benchee as `inputs:`.
  """
  def setup_posts(
        comment_counts \\ [
          2,
          16,
          70,
          500
        ]
      ) do
    account = fake_account!()
    user = fake_user!(account)

    inputs =
      for count <- comment_counts, into: %{} do
        post = PostFake.fake_post!(user)
        post_id = Types.uid(post)
        IO.puts("[benchmark] creating post with #{count} comments…")

        for _ <- 1..ceil(count / 2) do
          comment_l1 = PostFake.fake_comment!(user, post)
          PostFake.fake_comment!(user, comment_l1)
        end

        {"#{count} comments", post_id}
      end

    {user, account, inputs}
  end

  def post_page(user \\ nil, account \\ nil, inputs \\ nil) do
    Logger.configure(level: @log_level)

    {user, account, inputs} =
      if inputs do
        {user, account, inputs}
      else
        setup_posts()
      end

    # Activate StaticGenerator so cache writes actually happen.
    # Config.put is used (not Process.put) because Config.get only checks Process.get
    # in :test env — in dev/prod it reads from Application config.
    orig_adapters =
      Config.get([:bonfire_common, Bonfire.Common.Cache.HTTPPurge, :adapters], [])

    Config.put([:bonfire_common, Bonfire.Common.Cache.HTTPPurge, :adapters], [PurgeAdapter])

    guest_conn = build_conn()
    authed_conn = conn(user: user, account: account)

    # Pre-seed disk for every input so the disk-hit scenario works regardless of
    # the order Benchee picks for scenarios. The disk write is async, so poll
    # until the file appears (up to 2 s) before proceeding.
    for {_name, post_id} <- inputs do
      get(guest_conn, "/post/#{post_id}")

      disk_path = Path.join([StaticGenerator.dest_path(), "post", post_id, "index.html"])

      Enum.reduce_while(1..20, nil, fn _, _ ->
        if File.exists?(disk_path) do
          {:halt, :ok}
        else
          Process.sleep(100)
          {:cont, nil}
        end
      end)
    end

    Utils.maybe_apply(
      Benchee,
      :run,
      [
        %{
          # before_each / after_each scope :sync_load_thread to each timed call so that
          # the LiveView loads comments synchronously (they are normally deferred to async
          # after the socket connects, making the dead render incomparably fast).
          "browser pipeline: full render + comments (authenticated)" =>
            {fn post_id ->
               get(authed_conn, "/post/#{post_id}?cache=skip")
             end,
             before_each: fn post_id ->
               Process.put(:sync_load_thread, true)

               post_id
             end,
             after_each: fn _result -> Process.delete(:sync_load_thread) end},
          "browser_or_cacheable: dead render, uncached (unauthenticated)" => fn post_id ->
            get(guest_conn, "/post/#{post_id}?cache=skip")
          end,
          # before_each busts the cache so only the render itself is timed
          "browser_or_cacheable: dead render, before cache (unauthenticated)" =>
            {fn post_id -> get(guest_conn, "/post/#{post_id}") end,
             before_each: fn post_id ->
               PurgeAdapter.bust_urls(["/post/#{post_id}"])

               post_id
             end},
          # before_scenario evicts memory once; threshold=nil prevents promotion during the run
          "browser_or_cacheable: disk cache hit (unauthenticated)" =>
            {fn post_id -> get(guest_conn, "/post/#{post_id}") end,
             before_scenario: fn post_id ->
               disk_path =
                 Path.join([StaticGenerator.dest_path(), "post", post_id, "index.html"])

               unless File.exists?(disk_path) do
                 raise "disk cache file missing at #{disk_path} — pre-seeding failed. " <>
                         "Verify the StaticGenerator purge adapter was active and cacheable_response? returned true during setup."
               end

               Cache.remove("static_gen:/post/#{post_id}")
               Cache.remove("static_gen_hits:/post/#{post_id}")

               post_id
             end},
          # before_scenario ensures memory is populated for all iterations in this scenario
          "browser_or_cacheable: memory cache hit (unauthenticated)" =>
            {fn post_id -> get(guest_conn, "/post/#{post_id}") end,
             before_scenario: fn post_id ->
               unless Cache.get!("static_gen:/post/#{post_id}") do
                 Config.put(
                   [:bonfire_ui_common, MaybeStaticGeneratorPlug, :memory_cache_threshold],
                   1
                 )

                 get(guest_conn, "/post/#{post_id}")

                 Config.put(
                   [:bonfire_ui_common, MaybeStaticGeneratorPlug, :memory_cache_threshold],
                   nil
                 )
               end

               unless Cache.get!("static_gen:/post/#{post_id}") do
                 raise "memory cache entry still missing after promotion attempt for /post/#{post_id} — " <>
                         "check MaybeStaticGeneratorPlug threshold config and that the disk file exists."
               end

               post_id
             end}
        },
        [
          inputs: inputs,
          parallel: 1,
          warmup: 3,
          time: 15,
          memory_time: 2,
          reduction_time: 2,
          profile_after: true,
          formatters: formatters("benchmarks/output/post_page.html")
        ]
      ]
    )

    # Cleanup
    Config.put([:bonfire_common, Bonfire.Common.Cache.HTTPPurge, :adapters], orig_adapters)

    for {_name, post_id} <- inputs do
      post_url = "/post/#{post_id}"
      PurgeAdapter.bust_urls([post_url])
      Cache.remove("static_gen:#{post_url}")
      Cache.remove("static_gen_hits:#{post_url}")
    end

    Logger.configure(level: :debug)
  end

  if Config.get(:env) == :prod do
    defp formatters(_file) do
      [Benchee.Formatters.Console]
    end
  else
    defp formatters(file) do
      [
        {Benchee.Formatters.HTML, file: file},
        Benchee.Formatters.Console
      ]
    end
  end
end
