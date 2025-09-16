defmodule Bonfire.UI.Posts do
  use Bonfire.Common.Utils

  def render_replies(thread_id_or_replies, render_as \\ :html, opts \\ [])

  def render_replies(replies, render_as, opts) when is_list(replies) do
    Bonfire.Social.Threads.prepare_replies_tree(replies, replies_opts(opts))
    |> debug("repliesstreee")
    # |> Enum.map(fn {reply, child_replies} ->
    # render_recursive_replies(reply, child_replies, render_as)
    # end)
    |> recursive_replies(render_as, opts[:init_level] || 0)
  end

  def render_replies(thread_id, render_as, opts) when is_binary(thread_id) do
    opts = replies_opts(opts)

    replies =
      case Bonfire.Social.Threads.list_replies(thread_id, opts) |> debug("repliess") do
        %{edges: replies} when replies != [] ->
          replies
          |> render_replies(render_as, opts)

        _ ->
          nil
      end
  end

  defp replies_opts(opts \\ []) do
    [
      #  NOTE: we only want to include public ones
      current_user: nil,
      preload: [:with_subject, :with_post_content],
      limit: 5000,
      max_depth: 5000
      # sort_by: sort_by
    ]
    |> Keyword.merge(opts)
  end

  defp recursive_replies(replies, render_as \\ :html, level \\ 0) do
    replies
    |> Enum.map(fn {reply, child_replies} ->
      render_recursive_replies(reply, child_replies, render_as, level)
    end)
  end

  defp render_recursive_replies(reply, child_replies, render_as \\ :html, level \\ 0)

  defp render_recursive_replies(reply, child_replies, :markdown, level) do
    content = render_markdown_content(reply, level)

    children =
      child_replies
      |> Enum.map(fn {child, children} ->
        render_recursive_replies(child, children, :markdown, level + 1)
      end)
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n")

    result =
      if children != "" do
        content <> "\n" <> children
      else
        content
      end

    result
    |> Text.sentence_truncate(50_000)
  end

  defp render_recursive_replies(reply, child_replies, _html, _) do
    fields = [
      {"<strong>#{e(reply, :activity, :subject, :profile, :name, nil)} (#{e(reply, :activity, :subject, :character, :username, nil)}):</strong>",
       true},
      {e(reply, :activity, :object, :post_content, :name, nil), false},
      {e(reply, :activity, :object, :post_content, :summary, nil)
       |> Text.maybe_markdown_to_html(), false},
      {e(reply, :activity, :object, :post_content, :html_body, nil)
       |> Text.maybe_markdown_to_html(), false}
    ]

    content =
      fields
      |> Enum.map(fn
        {text, true} ->
          "<p>#{text}</p>"

        {text, false} when is_binary(text) ->
          text = String.trim(text) |> debug("txxxt")
          if text not in ["", "<p> </p>"], do: "<p>#{text}</p>", else: ""

        _ ->
          ""
      end)
      |> Enum.join("")

    children =
      child_replies
      |> Enum.map(fn {child, children} -> render_recursive_replies(child, children) end)
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("")

    """
    <blockquote class="ml-4 border-l-1">
    #{content}
    #{children}
    </blockquote>
    """
    |> Text.sentence_truncate(50_000)
  end

  def render_markdown_content(entity, level \\ 0, opts \\ []) do
    # base_url = URIs.base_url()
    only_body = Keyword.get(opts, :only_body, false)
    include_author = Keyword.get(opts, :include_author, true)

    {title, summary, body} =
      cond do
        entity = e(entity, :activity, :object, nil) ->
          {
            e(entity, :post_content, :name, nil),
            e(entity, :post_content, :summary, nil),
            e(entity, :post_content, :html_body, nil)
          }

        true ->
          {
            e(entity, :post_content, :name, nil),
            e(entity, :post_content, :summary, nil),
            e(entity, :post_content, :html_body, nil)
          }
      end

    body = body |> Text.make_links_absolute(:markdown)

    cond do
      only_body ->
        body

      include_author == false ->
        render_title_summary_body(nil, title, summary, body, level)

      true ->
        render_title_summary_body(entity, title, summary, body, level)
    end
  end

  defp render_title_summary_body(entity, title, summary, body, level) do
    author =
      e(entity, :activity, :subject, nil) || e(entity, :subject, nil) ||
        e(entity, :created, :creator, nil)

    author =
      e(author, :profile, :name, nil) ||
        e(author, :character, :username, nil)

    fields = [
      if(author, do: "**#{author}**:"),
      if(title, do: "## #{title}"),
      if(summary, do: "### #{summary}"),
      body
    ]

    content =
      fields
      |> Enum.map(fn
        text when is_binary(text) ->
          text = String.trim(text)
          if text not in ["", "<p> </p>", "<p></p>"], do: "#{text}\n", else: ""

        _ ->
          ""
      end)
      |> Enum.join("")
      |> String.trim()

    quote_prefix = String.duplicate("> ", level)

    content
    |> String.split("\n")
    |> Enum.map(&(quote_prefix <> &1))
    |> Enum.join("\n")
  end
end
