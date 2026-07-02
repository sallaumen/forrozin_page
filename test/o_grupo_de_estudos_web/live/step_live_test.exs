defmodule OGrupoDeEstudosWeb.StepLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Engagement
  alias OGrupoDeEstudos.Engagement.Comments.StepCommentQuery

  defp logged_in_conn(conn) do
    user = insert(:user)
    log_in_user(conn, user)
  end

  describe "access" do
    test "redirects to /login when not authenticated", %{conn: conn} do
      {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/steps/STBF")
    end

    test "redirects to /collection when step does not exist", %{conn: conn} do
      {:error, {:redirect, %{to: "/collection"}}} =
        live(logged_in_conn(conn), ~p"/steps/INEXISTENTE")
    end
  end

  describe "step detail" do
    test "displays step name and code", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, code: "STBF", name: "Base Frontal")
      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/steps/STBF")
      assert html =~ "Base Frontal"
      assert html =~ "STBF"
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
      insert(:step, section: section, code: "STWIP1", name: "Passo WIP", wip: true)
      {:error, {:redirect, %{to: "/collection"}}} = live(logged_in_conn(conn), ~p"/steps/STWIP1")
    end
  end

  describe "connections" do
    test "connections beyond the limit are collapsed until expanded", %{conn: conn} do
      section = insert(:section)
      source = insert(:step, section: section, code: "SRC", name: "Source")

      for i <- 1..12 do
        target = insert(:step, section: section, code: "T#{i}", name: "Target #{i}")
        insert(:connection, source_step: source, target_step: target)
      end

      {:ok, lv, html} = live(logged_in_conn(conn), ~p"/steps/SRC")

      assert html =~ "+2 mais"
      refute html =~ "ver menos"

      expanded = render_click(lv, "toggle_connections", %{})

      assert expanded =~ "ver menos"
      refute expanded =~ "+2 mais"
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
      step = insert(:step, section: section, code: "STFAV1")

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

  describe "bidirectional connection suggestions" do
    test "can set connection direction to 'from'", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)
      section = insert(:section)
      step = insert(:step, section: section, code: "DIR-T", approved: true)

      {:ok, lv, _html} = live(conn, ~p"/steps/#{step.code}")

      render_click(lv, "start_suggest_connection", %{})
      html = render_click(lv, "set_connection_direction", %{"direction" => "from"})

      assert html =~ "Vem de"
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

    test "start_suggest ignores fields outside the suggestible whitelist", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)
      section = insert(:section)
      insert(:step, section: section, code: "PS4", name: "Passo Protegido")

      {:ok, lv, _html} = live(conn, ~p"/steps/PS4")

      html = render_click(lv, "start_suggest", %{"field" => "password_hash"})

      refute html =~ "phx-submit=\"submit_suggestion\""
    end

    test "submit_suggestion without an active suggestion field is a no-op", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)
      section = insert(:section)
      insert(:step, section: section, code: "PS5", name: "Passo Quieto")

      {:ok, lv, _html} = live(conn, ~p"/steps/PS5")

      html = render_click(lv, "submit_suggestion", %{"value" => "Qualquer"})

      refute html =~ "Suas sugestões pendentes"
    end
  end

  describe "authorization boundary" do
    alias OGrupoDeEstudos.Encyclopedia.StepQuery

    test "regular user cannot delete a step via crafted event", %{conn: conn} do
      user = insert(:user)
      section = insert(:section)
      step = insert(:step, section: section, code: "AZ1", name: "Passo Vivo")

      {:ok, lv, _html} = live(log_in_user(conn, user), ~p"/steps/AZ1")
      render_click(lv, "delete_step", %{})

      assert %{id: step_id, deleted_at: nil} = StepQuery.get_by(code: "AZ1")
      assert step_id == step.id
    end

    test "regular user cannot approve a step via crafted event", %{conn: conn} do
      user = insert(:user)
      section = insert(:section)
      step = insert(:step, section: section, code: "AZ2", name: "Não Aprovado", approved: false)

      {:ok, lv, _html} = live(log_in_user(conn, user), ~p"/steps/AZ2")
      render_click(lv, "approve_step", %{"code" => "AZ2"})

      assert %{id: step_id, approved: false} = StepQuery.get_by(code: "AZ2")
      assert step_id == step.id
    end

    test "suggester can edit their own suggested step", %{conn: conn} do
      user = insert(:user)
      section = insert(:section)
      insert(:step, section: section, code: "AZ3", name: "Meu Passo", suggested_by: user)

      {:ok, lv, _html} = live(log_in_user(conn, user), ~p"/steps/AZ3")

      html =
        render_submit(lv, "update_step", %{"step" => %{"name" => "Meu Passo v2", "code" => "AZ3"}})

      assert html =~ "Meu Passo v2"
    end

    test "flash de erro de handle_event fica visivel no template", %{conn: conn} do
      user = insert(:user)
      section = insert(:section)
      insert(:step, section: section, code: "FL1", name: "Passo Flash Vivo")
      other_comment = insert(:step_comment)

      {:ok, lv, _html} = live(log_in_user(conn, user), ~p"/steps/FL1")

      html =
        render_click(lv, "delete_comment", %{"id" => other_comment.id, "type" => "step_comment"})

      assert html =~ "Sem permissão."
    end

    test "non-submitter cannot delete someone else's link via crafted event", %{conn: conn} do
      user = insert(:user)
      section = insert(:section)
      step = insert(:step, section: section, code: "AZ4", name: "Com Link")
      link = insert(:step_link, step: step, approved: true)

      {:ok, lv, _html} = live(log_in_user(conn, user), ~p"/steps/AZ4")
      render_click(lv, "delete_link", %{"link-id" => link.id})

      assert OGrupoDeEstudos.Encyclopedia.StepLinkQuery.list_by(step_id: step.id) != []
    end
  end
end
