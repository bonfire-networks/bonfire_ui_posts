defmodule Bonfire.UI.Posts.MarkdownPostController do
  use Bonfire.UI.Common.Web, :controller

  def download_markdown(conn, %{"id" => id} = params) do
    case Bonfire.Posts.read(id,
           current_user: current_user(conn),
           preload: [:with_post_content, :with_media, :with_creator]
         ) do
      {:ok, post} ->
        # debug(post)
        markdown_content =
          convert_activity_to_markdown(post,
            with_frontmatter: params["frontmatter"] == "true",
            with_replies: params["replies"] == "true"
          )

        filename = "#{id}.md"

        conn
        |> put_resp_content_type("text/markdown")
        |> put_resp_header("content-disposition", ~s[attachment; filename="#{filename}"])
        |> send_resp(200, markdown_content)

      {:error, :not_found} ->
        conn
        |> put_resp_content_type("text/markdown")
        |> send_resp(404, "Post not found")

      error ->
        error(error, "Could not load post")

        conn
        |> put_resp_content_type("text/markdown")
        |> send_resp(500, "Unable to generate markdown")
    end
  end

  def convert_activity_to_markdown(activity, opts \\ [])

  def convert_activity_to_markdown(
        %{activity: %{object: %{id: _} = object} = activity} = _post,
        opts
      ) do
    convert_post_to_markdown(activity, object, opts)
  end

  def convert_activity_to_markdown(%{activity: %{id: _} = activity} = object, opts) do
    convert_post_to_markdown(activity, object, opts)
  end

  def convert_post_to_markdown(activity \\ nil, post, opts) do
    base_url = URIs.base_url()
    with_replies = opts[:with_replies]
    with_frontmatter = opts[:with_frontmatter]

    root_content =
      if with_frontmatter do
        Bonfire.UI.Posts.render_markdown_content(post, 0, only_body: true)
      else
        Bonfire.UI.Posts.render_markdown_content(post, 0, include_author: false)
      end

    replies =
      if with_replies do
        Bonfire.UI.Posts.render_replies(id(post), :markdown, include_author: true, init_level: 1)
      else
        []
      end

    content =
      ([root_content] ++ replies)
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join("\n\n")

    if with_frontmatter do
      # TODO: tags
      """
      ---
      title: "#{e(post, :post_content, :name, nil)}"
      description: "#{e(post, :post_content, :summary, "") |> String.replace(~r/[\r\n]+/, " ") |> String.replace("\"", "'")}"
      uri: #{URIs.canonical_url(post)}
      date: #{DatesTimes.format(id(post))}  
      author: "#{e(post, :created, :creator, :profile, :name, nil) || e(post, :created, :creator, :character, :username, nil)}"
      image: #{get_primary_image(e(activity, :media, []) || e(post, :media, [])) |> Media.media_url()}
      tags: 

      ---

      #{content}

      """
    else
      content
    end
  end

  def get_primary_image(files) when is_list(files) do
    Enum.find(files, &is_primary_image?/1)
  end

  def get_primary_image(file) when is_map(file) do
    # Handle single file case
    if is_primary_image?(file) do
      file
    else
      nil
    end
  end

  def get_primary_image(_), do: nil

  defp is_primary_image?(%{media: %{metadata: %{"primary_image" => true}}}), do: true
  defp is_primary_image?(%{metadata: %{"primary_image" => true}}), do: true
  defp is_primary_image?(_), do: false
end
