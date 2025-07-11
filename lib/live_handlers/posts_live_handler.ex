defmodule Bonfire.Posts.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Untangle
  use Bonfire.Common.Utils
  alias Bonfire.Posts
  # alias Bonfire.Social.PostContents
  # alias Bonfire.Data.Social.Post
  # alias Ecto.Changeset

  def handle_event("post", %{"create_object_type" => "message"} = params, socket) do
    maybe_apply(Bonfire.Messages.LiveHandler, :send_message, [params, socket])
    # |> debug("ress")
  end

  def handle_event("post", %{"post" => %{"create_object_type" => "message"}} = params, socket) do
    maybe_apply(Bonfire.Messages.LiveHandler, :send_message, [params, socket])
    # |> debug("ress")
  end

  # if not a message, it's a post by default
  def handle_event("post", params, socket) do
    debug(params, "post_paramssss")
    upload_metadata = params["upload_metadata"]

    attrs =
      params
      # Remove upload_metadata before conversion
      |> Map.delete("upload_metadata")
      |> input_to_atoms(
        discard_unknown_keys: false,
        also_discard_unknown_nested_keys: false,
        force: false,
        including_values: false
      )
      |> debug("post_attrssss")

    # debug(e(assigns(socket), :showing_within, nil), "SHOWING")
    current_user = current_user_required!(socket)

    with %{valid?: true} <- post_changeset(attrs, current_user),
         uploaded_media <- live_upload_files(current_user, upload_metadata, socket),
         opts <-
           [
             #  current_user: current_user,
             context: assigns(socket)[:__context__] || current_user,
             post_attrs:
               Bonfire.Posts.prepare_post_attrs(attrs)
               |> Map.put(:uploaded_media, uploaded_media),
             boundary: e(params, "to_boundaries", "mentions"),
             to_circles: e(params, "to_circles", []),
             context_id: e(params, "context_id", nil),
             return_epic_on_error: true
           ]
           |> debug("publish opts"),
         {:ok, published} <- Bonfire.Posts.publish(opts) do
      debug(published, "published!")

      activity = e(published, :activity, nil)
      thread = e(activity, :replied, :thread, nil) || e(activity, :replied, :thread_id, nil)
      object_id = e(activity, :object_id, nil) || e(activity, :object, :id, nil)

      thread_level = length(e(activity, :replied, :path, []))

      thread_url =
        if thread do
          if is_struct(thread) do
            path(thread)
          else
            "/discussion/#{uid(thread)}"
          end
        else
          nil
        end

      permalink =
        if thread_url && uid(thread) != object_id do
          if thread_level != 0 do
            "#{thread_url}/reply/#{thread_level}/#{object_id}"
          else
            "#{thread_url}/reply/#{object_id}"
          end
        else
          "#{path(e(activity, :object, nil) || activity)}#"
        end

      {
        :noreply,
        socket

        # |> Bonfire.UI.Common.SmartInput.LiveHandler.close_smart_input()
        |> push_event("smart_input:reset", %{})
        |> Bonfire.UI.Common.SmartInput.LiveHandler.reset_input()
        |> assign_flash(
          :info,
          "<div class='flex justify-between items-center'> <span>#{l("Posted!")} </span><a href='#{permalink}' class='btn-active btn btn-sm'>#{l("Show")}</a></div>"
        )
        # |> patch_to(current_url(socket), fallback: path(published)) # so the flash appears - TODO: causes a conflict between the activity coming in via pubsub

        # assign_generic(socket,
        #   feed: [%{published.activity | object_post: published.post, subject_user: current_user_required!(socket)}] ++ Map.get(assigns(socket), :feed, [])
        # )
      }

      # else
      #   {:error, error} ->
      #     {
      #       :noreply,
      #       socket
      #       |> assign_error(error)
      #     }
      #   e ->
      #     error = Errors.error_msg(e)
      #     error(error)

      #     {
      #       :noreply,
      #       socket
      #       |> assign_error("Could not post 😢 (#{error})")
      #     }
    end
  end

  def handle_event("edit", %{"post_id" => id} = attrs, socket) do
    current_user = current_user_required!(socket)

    with {:ok, updated} <- Bonfire.Social.PostContents.edit(current_user, id, attrs) do
      # TODO: update activity assigns with edits
      Bonfire.UI.Common.OpenModalLive.close()

      {:noreply,
       socket
       |> assign(:object, Map.put(assigns(socket)[:object] || %{}, :post_content, updated))
       |> assign_flash(:info, l("Edited!"))}
    else
      {:ok, :no_changes} ->
        Bonfire.UI.Common.OpenModalLive.close()
        {:noreply, socket}

      nil ->
        Bonfire.UI.Common.OpenModalLive.close()
        {:noreply, socket}
    end
  end

  # def toggle_minimized_composer(js \\ %JS{}) do
  #   js
  #   |> JS.toggle(to: ".smart_input_show_on_minimize", in: "fade-in-scale", out: "fade-out-scale")
  # end

  def handle_event("write_error", _, socket) do
    Bonfire.UI.Common.NotificationLive.error_template(assigns(socket))
    |> write_feedback(socket)
  end

  def handle_event("write_feedback", _, socket) do
    write_feedback(
      Settings.get(
        [:ui, :feedback_post_template],
        "I have a suggestion for Bonfire: \n\n@BonfireBuilders #bonfire_feedback",
        socket
      ),
      socket
    )
  end

  # def handle_event("switch_thread_mode", %{"thread_mode" => thread_mode} = _attrs, socket) do
  #   IO.inspect(thread_mode, label: "THREAD MODE")

  #   if thread_mode == "flat" do
  #     {:noreply,
  #      assign(socket,
  #        thread_mode: :thread
  #      )}
  #   else
  #     {:noreply,
  #      assign(socket,
  #        thread_mode: :flat
  #      )}
  #   end
  # end

  def handle_event("input", %{"circles" => selected_circles} = _attrs, socket)
      when is_list(selected_circles) and selected_circles != [] do
    {:noreply,
     Bonfire.Boundaries.Circles.LiveHandler.set_circles_tuples(
       :to_circles,
       selected_circles,
       socket
     )}
  end

  # no circle
  def handle_event("input", _attrs, socket) do
    {:noreply,
     socket
     |> assign(to_circles: [])}
  end

  # def handle_event("add_data", %{"activity" => activity_id}, socket) do
  #   IO.inspect("TEST")
  #   maybe_send_update(Bonfire.UI.Social.ActivityLive, "activity_component_" <> activity_id, activity_id: activity_id)
  #   {:noreply, socket}
  # end

  def write_feedback(text, socket) do
    {:noreply,
     socket
     |> Bonfire.UI.Common.SmartInput.LiveHandler.set_smart_input_text(text)}
  end

  def post_changeset(attrs \\ %{}, creator) do
    debug(attrs, "ATTRS33")
    Posts.changeset(:create, attrs, creator)
    # |> debug("pc")
  end
end
