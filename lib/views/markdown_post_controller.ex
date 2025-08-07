defmodule Bonfire.UI.Posts.MarkdownPostController do
  use Bonfire.UI.Common.Web, :controller

  def download_markdown(conn, %{"id" => id}) do
    case Bonfire.Posts.read(id,
           current_user: current_user(conn),
           preload: [:with_post_content, :with_media, :with_creator]
         ) do
      {:ok, post} ->
        # debug(post)
        markdown_content = convert_to_markdown(post)
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

  defp convert_to_markdown(%{activity: %{object: %{id: _} = object} = activity} = _post) do
    convert_to_markdown(activity, object)
  end

  defp convert_to_markdown(%{activity: %{id: _} = activity} = object) do
    convert_to_markdown(activity, object)
  end

  defp convert_to_markdown(activity, post) do
    # TODO: tags
    """
    ---
    title: #{e(post, :post_content, :name, "")}
    description: #{e(post, :post_content, :summary, "") |> String.replace(~r/[\r\n]+/, " ")}
    uri: #{URIs.canonical_url(post)}
    date: #{DatesTimes.format(id(post))}  
    author: #{e(post, :created, :creator, :profile, :name, nil) || e(post, :created, :creator, :character, :username, nil)}
    image: #{get_primary_image(e(activity, :media, [])) |> Media.media_url()}
    tags: 

    ---

    #{e(post, :post_content, :html_body, "") |> make_markdown_links_absolute(URIs.base_url())}

    """
  end

  defp make_markdown_links_absolute(markdown, base_url) do
    Regex.replace(~r/(\]\()\/([^)]+)\)/, markdown, "\\1#{base_url}/\\2)")
    |> Regex.replace(~r/(!\[.*?\]\()\/([^)]+)\)/, ..., "\\1#{base_url}/\\2)")
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
