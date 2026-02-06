defmodule Bonfire.UI.Posts.PostLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  # import Untangle
  alias Bonfire.Social.Threads

  declare_extension("UI for posts",
    icon: "ph:article-ny-times-duotone",
    emoji: "📝",
    description: l("User interface for writing and reading posts.")
  )

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, session, socket) do
    # is_guest? = is_nil(current_user_id(socket))

    {:ok,
     socket
     |> assign(
       page_title: l("Post"),
       #  is_guest?: is_guest?,
       #  without_sidebar: is_guest?,
       #  without_secondary_widgets: is_guest?,
       #  no_header: is_guest?,
       no_mobile_header: true,
       thread_title: "Post",
       page: "discussion",
       #  to_circles: [],
       participants: nil,

       #  smart_input_opts: %{prompt: l("Reply")},
       activity: nil,
       include_path_ids: nil,
       back: true,
       showing_within: :thread,
       object: nil,
       #  sidebar_widgets: [
       #    users: [
       #      secondary: [
       #       {Bonfire.Tag.Web.WidgetTagsLive, []}
       #      ]
       #    ],
       #    guests: [
       #      secondary: nil
       #    ]
       #  ],
       #  without_sidebar: true,
       post_id: nil,
       thread_id: nil,
       reply_id: nil,
       page_info: nil,
       replies: nil,
       threaded_replies: nil,
       thread_mode:
         (maybe_to_atom(e(params, "mode", nil)) ||
            Settings.get(
              [Bonfire.UI.Social.ThreadLive, :thread_mode],
              nil,
              assigns(socket)[:__context__]
            ) || :nested)
         |> debug("thread mode"),
       search_placeholder: nil,
       #  to_boundaries: nil,
       loading: false,
       accepts_markdown?: accepts_markdown?(session)
     )}
  end

  def handle_params(%{"id" => "comment_" <> comment_id} = params, _url, socket)
      when is_binary(comment_id) do
    # deprecated - keeping to avoid broken links
    debug(comment_id, "comment_id that needs redirection")

    # Try to find the thread_id for this comment (optimized query)
    current_user = current_user(socket)

    with thread_id when is_binary(thread_id) <-
           Threads.fetch_thread_id(comment_id, current_user: current_user) do
      redirect_to_thread_comment(socket, thread_id, comment_id)
    else
      error ->
        debug(error, "Could not find thread for comment")

        {:noreply,
         assign_error(socket, l("Comment not found or you don't have permission to view it"))}
    end
  end

  def handle_params(%{"id" => thread_id} = params, _url, socket) do
    # Strip .md suffix if present - TOOD: do same for RSS
    reply_id = e(params, "reply_id", nil)

    maybe_md_id = String.replace_suffix(reply_id || thread_id, ".md", "")

    # Check if requesting markdown format
    if (maybe_md_id != thread_id and maybe_md_id != reply_id) or
         assigns(socket)[:accepts_markdown?] do
      {:noreply, redirect_to(socket, "/post/markdown/#{maybe_md_id}")}
    else
      # render the HTML view as usual

      socket =
        socket
        |> assign(
          params: params,
          post_id: thread_id,
          thread_id: thread_id,
          reply_id: reply_id,
          #  url: url
          include_path_ids:
            Bonfire.Social.Threads.LiveHandler.maybe_include_path_ids(
              reply_id,
              e(params, "level", nil),
              e(assigns(socket), :__context__, nil) || assigns(socket)
            )
        )

      with %Phoenix.LiveView.Socket{} = socket <-
             Bonfire.Social.Objects.LiveHandler.load_object_assigns(socket) do
        {:noreply, socket}
      else
        {:error, :not_found} ->
          error(thread_id, "Post not found")
          {:error, :not_found}

        #   {:noreply, socket
        #   |> assign(:object, :not_found)}

        {:error, e} ->
          error(e)
          {:noreply, assign_error(socket, e)}

        other ->
          error(other)
          {:noreply, socket}
      end
    end
  end

  def handle_params(_params, _url, socket) do
    {:noreply,
     socket
     |> redirect_to(path(:write))}
  end

  defp redirect_to_thread_comment(socket, thread_id, comment_id) do
    debug(thread_id, "redirecting to thread")

    redirect_path = "/discussion/#{thread_id}/reply/#{comment_id}"

    {:noreply,
     socket
     |> redirect_to(redirect_path)}
  end

  # Check Accept header from session
  defp accepts_markdown?(session) do
    case Map.get(session, "accept_header") do
      accept_header when is_binary(accept_header) ->
        String.contains?(accept_header, "text/markdown")

      _ ->
        false
    end
  end
end
