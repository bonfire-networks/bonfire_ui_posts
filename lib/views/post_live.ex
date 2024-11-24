defmodule Bonfire.UI.Posts.PostLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  # import Untangle

  declare_extension("UI for posts",
    icon: "icomoon-free:blog",
    emoji: "📝",
    description: l("User interface for writing and reading posts.")
  )

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, _session, socket) do
    # is_guest? = is_nil(current_user_id(assigns(socket)))

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
       nav_items: Bonfire.Common.ExtensionModule.default_nav(),

       #  smart_input_opts: %{prompt: l("Reply")},
       activity: nil,
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
       #  reply_to_id: nil,
       thread_mode: maybe_to_atom(e(params, "mode", nil)),
       search_placeholder: nil,
       #  to_boundaries: nil,
       loading: false
     )}
  end

  def handle_params(%{"id" => id} = params, _url, socket) do
    socket =
      socket
      |> assign(
        params: params,
        post_id: id,
        thread_id: id
        #  url: url
        #  reply_to_id: e(params, "reply_to_id", id)
      )

    with %Phoenix.LiveView.Socket{} = socket <-
           Bonfire.Social.Objects.LiveHandler.load_object_assigns(socket) do
      {:noreply, socket}
    else
      {:error, :not_found} ->
        error(id, "Post not found")
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

  def handle_params(_params, _url, socket) do
    {:noreply,
     socket
     |> redirect_to(path(:write))}
  end
end
