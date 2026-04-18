defmodule OGrupoDeEstudosWeb.UI.CommentThreadTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.UI.CommentThread

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp user(overrides \\ []) do
    defaults = %{id: "u1", username: "tavano"}
    Map.merge(defaults, Map.new(overrides))
  end

  defp comment(overrides \\ []) do
    defaults = %{
      id: "c1",
      body: "Ótimo passo!",
      like_count: 0,
      reply_count: 0,
      deleted_at: nil,
      inserted_at: NaiveDateTime.utc_now(),
      user: user(),
      user_id: "u1"
    }

    Map.merge(defaults, Map.new(overrides))
  end

  defp profile_comment(overrides \\ []) do
    defaults = %{
      id: "pc1",
      body: "Bom perfil!",
      like_count: 0,
      reply_count: 0,
      deleted_at: nil,
      inserted_at: NaiveDateTime.utc_now(),
      author: user(),
      author_id: "u1"
    }

    Map.merge(defaults, Map.new(overrides))
  end

  defp empty_likes, do: %{liked_ids: MapSet.new(), counts: %{}}

  defp base_assigns(overrides \\ []) do
    defaults = [
      comments: [comment()],
      current_user: user(),
      likes_map: empty_likes(),
      comment_type: "step_comment",
      parent_id: "step-1"
    ]

    Map.new(Keyword.merge(defaults, overrides))
  end

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  describe "comment_thread/1" do
    test "has data-ui attribute" do
      html = render_component(&CommentThread.comment_thread/1, base_assigns())
      assert html =~ ~s(data-ui="comment-thread")
    end

    test "renders comment body text" do
      html = render_component(&CommentThread.comment_thread/1, base_assigns())
      assert html =~ "Ótimo passo!"
    end

    test "renders username linked to /users/:username" do
      html = render_component(&CommentThread.comment_thread/1, base_assigns())
      assert html =~ ~s(href="/users/tavano")
      assert html =~ "tavano"
    end

    test "renders new comment form at the bottom" do
      html = render_component(&CommentThread.comment_thread/1, base_assigns())
      assert html =~ ~s(phx-submit="create_comment")
      assert html =~ ~s(name="body")
      assert html =~ "Escrever comentário"
    end

    test "renders like button with toggle_comment_like event" do
      html = render_component(&CommentThread.comment_thread/1, base_assigns())
      assert html =~ ~s(phx-click="toggle_comment_like")
      assert html =~ ~s(phx-value-type="step_comment")
    end

    test "like button shows unliked state when comment not in liked_ids" do
      html = render_component(&CommentThread.comment_thread/1, base_assigns())
      # Heroicons renders as a <span> with class "hero-heart ..."
      assert html =~ ~r/class="hero-heart [^"]*text-ink-400/
      refute html =~ "hero-heart-solid"
    end

    test "like button shows liked state when comment in liked_ids" do
      likes_map = %{liked_ids: MapSet.new(["c1"]), counts: %{}}
      html = render_component(&CommentThread.comment_thread/1, base_assigns(likes_map: likes_map))
      assert html =~ "hero-heart-solid"
      assert html =~ "text-accent-red"
    end

    test "renders tombstone for soft-deleted comment" do
      deleted = comment(deleted_at: NaiveDateTime.utc_now(), body: "segredo")
      html = render_component(&CommentThread.comment_thread/1, base_assigns(comments: [deleted]))
      assert html =~ "Comentário removido"
      refute html =~ "segredo"
    end

    test "tombstone does not show username or actions" do
      deleted = comment(deleted_at: NaiveDateTime.utc_now())
      html = render_component(&CommentThread.comment_thread/1, base_assigns(comments: [deleted]))
      refute html =~ ~s(href="/users/tavano")
      refute html =~ "toggle_comment_like"
    end

    test "renders reply button for root comments" do
      html = render_component(&CommentThread.comment_thread/1, base_assigns())
      assert html =~ ~s(phx-click="start_reply")
      assert html =~ "Responder"
    end

    test "does not show reply form when replying_to is nil" do
      html = render_component(&CommentThread.comment_thread/1, base_assigns())
      refute html =~ ~s(phx-submit="create_reply")
    end

    test "shows reply form when replying_to matches comment id" do
      html =
        render_component(&CommentThread.comment_thread/1, base_assigns(replying_to: "c1"))

      assert html =~ ~s(phx-submit="create_reply")
      assert html =~ ~s(phx-value-parent-id="c1")
      assert html =~ "Escrever resposta"
    end

    test "does not show reply form when replying_to is a different comment id" do
      html =
        render_component(&CommentThread.comment_thread/1, base_assigns(replying_to: "other-id"))

      refute html =~ ~s(phx-submit="create_reply")
    end

    test "renders replies indented when replies_map has entries" do
      reply = comment(id: "r1", body: "Concordo!", reply_count: 0)
      replies_map = %{"c1" => [reply]}

      html =
        render_component(
          &CommentThread.comment_thread/1,
          base_assigns(replies_map: replies_map)
        )

      assert html =~ "Concordo!"
      assert html =~ "border-l-2"
    end

    test "toggle_replies button appears when reply_count > 0" do
      c = comment(reply_count: 3)
      html = render_component(&CommentThread.comment_thread/1, base_assigns(comments: [c]))
      assert html =~ ~s(phx-click="toggle_replies")
      assert html =~ "3 respostas"
    end

    test "toggle_replies button does not appear when reply_count is 0" do
      html = render_component(&CommentThread.comment_thread/1, base_assigns())
      refute html =~ ~s(phx-click="toggle_replies")
    end

    test "delete button not shown when current_user is not owner and not admin" do
      other_user = user(id: "u2", username: "outro")

      html =
        render_component(
          &CommentThread.comment_thread/1,
          base_assigns(current_user: other_user, is_admin: false)
        )

      refute html =~ ~s(phx-click="delete_comment")
    end

    test "delete button shown when current_user is owner" do
      html = render_component(&CommentThread.comment_thread/1, base_assigns())
      assert html =~ ~s(phx-click="delete_comment")
      assert html =~ ~s(data-confirm="Apagar este comentário?")
    end

    test "delete button shown when is_admin is true even if not owner" do
      other_user = user(id: "u2", username: "admin")

      html =
        render_component(
          &CommentThread.comment_thread/1,
          base_assigns(current_user: other_user, is_admin: true)
        )

      assert html =~ ~s(phx-click="delete_comment")
    end

    test "delete button emits phx-value-type matching comment_type" do
      html =
        render_component(
          &CommentThread.comment_thread/1,
          base_assigns(comment_type: "sequence_comment")
        )

      assert html =~ ~s(phx-value-type="sequence_comment")
    end

    test "supports ProfileComment with :author association" do
      pc = profile_comment()

      html =
        render_component(
          &CommentThread.comment_thread/1,
          base_assigns(comments: [pc], comment_type: "profile_comment")
        )

      assert html =~ "Bom perfil!"
      assert html =~ ~s(href="/users/tavano")
    end

    test "delete button shown for ProfileComment owner via author_id" do
      pc = profile_comment()

      html =
        render_component(
          &CommentThread.comment_thread/1,
          base_assigns(comments: [pc], comment_type: "profile_comment")
        )

      assert html =~ ~s(phx-click="delete_comment")
    end

    test "renders empty thread with only new comment form" do
      html = render_component(&CommentThread.comment_thread/1, base_assigns(comments: []))
      assert html =~ ~s(data-ui="comment-thread")
      assert html =~ ~s(phx-submit="create_comment")
      refute html =~ "Ótimo passo!"
    end
  end
end
