defmodule OGrupoDeEstudosWeb.StepLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.StepLive
  alias OGrupoDeEstudos.Engagement
  alias OGrupoDeEstudos.Engagement.Comments.StepCommentQuery

  defp logged_in_conn(conn) do
    user = insert(:user)
    log_in_user(conn, user)
  end

  describe "access" do
    test "redirects to /login when not authenticated", %{conn: conn} do
      {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/steps/BF")
    end

    test "redirects to /collection when step does not exist", %{conn: conn} do
      {:error, {:redirect, %{to: "/collection"}}} =
        live(logged_in_conn(conn), ~p"/steps/INEXISTENTE")
    end
  end

  describe "step detail" do
    test "displays step name and code", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, code: "BF", name: "Base Frontal")
      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/steps/BF")
      assert html =~ "Base Frontal"
      assert html =~ "BF"
    end

    test "displays technical note when present", %{conn: conn} do
      section = insert(:section)

      insert(:step,
        section: section,
        code: "BF2",
        name: "Base Frontal",
        note: "Descrição mecânica do passo."
      )

      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/steps/BF2")
      assert html =~ "Descrição mecânica do passo."
    end

    test "does not display wip step for regular user", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, code: "WIP1", name: "Passo WIP", wip: true)
      {:error, {:redirect, %{to: "/collection"}}} = live(logged_in_conn(conn), ~p"/steps/WIP1")
    end
  end

  describe "youtube_embed_url/1" do
    test "returns {:youtube, embed_url} for standard youtube.com/watch?v= URL" do
      assert {:youtube, "https://www.youtube.com/embed/dQw4w9WgXcQ"} =
               StepLive.youtube_embed_url("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    end

    test "returns {:youtube, embed_url} for youtu.be short URL" do
      assert {:youtube, "https://www.youtube.com/embed/dQw4w9WgXcQ"} =
               StepLive.youtube_embed_url("https://youtu.be/dQw4w9WgXcQ")
    end

    test "returns {:youtube, embed_url} ignoring extra query params" do
      assert {:youtube, "https://www.youtube.com/embed/dQw4w9WgXcQ"} =
               StepLive.youtube_embed_url(
                 "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42s&list=PLabc"
               )
    end

    test "returns :external for non-YouTube URL" do
      assert :external = StepLive.youtube_embed_url("https://vimeo.com/123456")
    end

    test "returns :external for youtube.com without video id" do
      assert :external = StepLive.youtube_embed_url("https://www.youtube.com/watch")
    end

    test "returns :external for nil" do
      assert :external = StepLive.youtube_embed_url(nil)
    end

    test "returns :external for empty youtu.be" do
      assert :external = StepLive.youtube_embed_url("https://youtu.be/")
    end
  end

  describe "step like" do
    test "toggle_step_like changes liked state", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)
      section = insert(:section)
      step = insert(:step, section: section, code: "LK1")

      {:ok, view, _html} = live(conn, ~p"/steps/#{step.code}")

      view |> render_click("toggle_step_like", %{"id" => step.id})

      assert Engagement.liked?(user.id, "step", step.id)
    end
  end

  describe "step favorite" do
    test "toggle_step_favorite creates favorite and auto-likes", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)
      section = insert(:section)
      step = insert(:step, section: section, code: "FAV1")

      {:ok, view, _html} = live(conn, ~p"/steps/#{step.code}")

      view |> render_click("toggle_step_favorite", %{"id" => step.id})

      assert Engagement.favorited?(user.id, "step", step.id)
      assert Engagement.liked?(user.id, "step", step.id)
    end
  end

  describe "step comments" do
    test "create_comment adds a comment", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)
      section = insert(:section)
      step = insert(:step, section: section, code: "CMT1")

      {:ok, view, _html} = live(conn, ~p"/steps/#{step.code}")

      view |> render_submit("create_comment", %{"body" => "Great step!"})

      comments = Engagement.list_step_comments(step.id)
      assert length(comments) == 1
      assert hd(comments).body == "Great step!"
    end

    test "create_reply adds a reply to a comment", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)
      section = insert(:section)
      step = insert(:step, section: section, code: "RPL1")
      {:ok, parent} = Engagement.create_step_comment(user, step.id, %{body: "Parent"})

      {:ok, view, _html} = live(conn, ~p"/steps/#{step.code}")

      view |> render_submit("create_reply", %{"body" => "Reply!", "parent-id" => parent.id})

      replies = Engagement.list_replies(StepCommentQuery, parent.id)
      assert length(replies) == 1
    end

    test "delete_comment removes comment when no replies", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)
      section = insert(:section)
      step = insert(:step, section: section, code: "DEL1")
      {:ok, comment} = Engagement.create_step_comment(user, step.id, %{body: "Delete me"})

      {:ok, view, _html} = live(conn, ~p"/steps/#{step.code}")

      view |> render_click("delete_comment", %{"id" => comment.id, "type" => "step_comment"})

      assert Engagement.list_step_comments(step.id) == []
    end

    test "toggle_comment_like likes a comment", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)
      section = insert(:section)
      step = insert(:step, section: section, code: "CLK1")
      other = insert(:user)
      {:ok, comment} = Engagement.create_step_comment(other, step.id, %{body: "Like me"})

      {:ok, view, _html} = live(conn, ~p"/steps/#{step.code}")

      view |> render_click("toggle_comment_like", %{"type" => "step_comment", "id" => comment.id})

      assert Engagement.liked?(user.id, "step_comment", comment.id)
    end
  end

  describe "pending suggestions visibility" do
    test "shows user's pending suggestions on the step page", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)
      section = insert(:section)
      step = insert(:step, section: section, code: "PS1", name: "Passo Sugestão")

      OGrupoDeEstudos.Suggestions.create(user, %{
        target_type: "step",
        target_id: step.id,
        action: "edit_field",
        field: "name",
        old_value: "Passo Sugestão",
        new_value: "Nome Melhorado"
      })

      {:ok, _lv, html} = live(conn, ~p"/steps/PS1")

      assert html =~ "Suas sugestões pendentes"
      assert html =~ "Nome Melhorado"
    end

    test "does not show other user's pending suggestions", %{conn: conn} do
      user = insert(:user)
      other = insert(:user)
      conn = log_in_user(conn, user)
      section = insert(:section)
      step = insert(:step, section: section, code: "PS2", name: "Outro Passo")

      OGrupoDeEstudos.Suggestions.create(other, %{
        target_type: "step",
        target_id: step.id,
        action: "edit_field",
        field: "name",
        old_value: "Outro Passo",
        new_value: "Sugestão Alheia"
      })

      {:ok, _lv, html} = live(conn, ~p"/steps/PS2")

      refute html =~ "Suas sugestões pendentes"
      refute html =~ "Sugestão Alheia"
    end

    test "updates pending list after submitting suggestion", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)
      section = insert(:section)
      _step = insert(:step, section: section, code: "PS3", name: "Passo Flash")

      {:ok, lv, _html} = live(conn, ~p"/steps/PS3")

      lv |> render_click("start_suggest", %{"field" => "name"})
      lv |> render_click("submit_suggestion", %{"value" => "Nome Novo"})

      html = render(lv)

      # After submit, pending suggestions block should appear
      assert html =~ "Suas sugestões pendentes"
      assert html =~ "Nome Novo"
    end
  end
end
