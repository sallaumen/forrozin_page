defmodule OGrupoDeEstudosWeb.CollectionLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Engagement

  defp logged_in_conn(conn) do
    user = insert(:user)
    log_in_user(conn, user)
  end

  describe "access" do
    test "redirects to /login when not authenticated", %{conn: conn} do
      {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/collection")
    end
  end

  describe "mount — authenticated" do
    test "displays titles of registered sections", %{conn: conn} do
      insert(:section, title: "Bases", position: 1)
      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/collection")
      assert html =~ "Bases"
    end

    test "renders collection inside a wide desktop shell", %{conn: conn} do
      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/collection")

      assert html =~ ~s(id="collection-shell")
      assert html =~ ~s(data-layout="wide")
      assert html =~ ~s(id="collection-controls")
    end

    test "does not display wip steps when expanding the section", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, name: "Base frontal", wip: false)
      insert(:step, section: section, name: "Sacada Suspensa", wip: true)
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_click(lv, "expand_all", %{})
      assert html =~ "Base frontal"
      refute html =~ "Sacada Suspensa"
    end

    test "desktop notification dropdown marks visible notifications as read", %{conn: conn} do
      user = insert(:user)
      actor = insert(:user, name: "Maria Seguidora")

      insert(:notification,
        user: user,
        actor: actor,
        action: "followed_user",
        group_key: "follow:#{user.id}",
        target_type: "profile",
        target_id: actor.id,
        parent_type: "profile",
        parent_id: actor.id,
        read_at: nil
      )

      {:ok, lv, _html} = live(log_in_user(conn, user), ~p"/collection")

      html =
        lv
        |> element("#top-nav-notifications-button")
        |> render_click()

      assert html =~ ~s(id="top-nav-notifications-panel")
      assert html =~ "Maria Seguidora"
      assert html =~ "começou a te seguir"
      assert Engagement.unread_count(user.id) == 0
    end

    test "does not display draft steps", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, name: "Publicado", status: "published")
      insert(:step, section: section, name: "Rascunho", status: "draft")
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_click(lv, "expand_all", %{})
      assert html =~ "Publicado"
      refute html =~ "Rascunho"
    end
  end

  describe "editorial navigation" do
    test "renders the overview grid with a filter toggle and suggest card", %{conn: conn} do
      insert(:section, title: "Bases", position: 1)

      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")

      assert has_element?(lv, "#collection-overview-grid")
      assert has_element?(lv, "#collection-filter-toggle")
      assert has_element?(lv, "#collection-suggest-card")
    end

    test "enter_section reorganizes the page around the selected section", %{conn: conn} do
      category = insert(:category, name: "bases", label: "Bases", color: "#2e9f6b")
      section = insert(:section, title: "Bases", code: "B", position: 1, category: category)

      insert(:step,
        section: section,
        category: category,
        code: "BF",
        name: "Base frontal",
        like_count: 2
      )

      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      render_click(lv, "enter_section", %{"section_id" => section.id})

      assert has_element?(lv, "#collection-drilldown-shell")
      assert has_element?(lv, "#collection-breadcrumb")
      assert has_element?(lv, "#collection-featured-step-BF")
    end

    test "opening suggest inside a section preselects that section", %{conn: conn} do
      category = insert(:category, name: "sacadas", label: "Sacadas", color: "#ef5b8d")
      section = insert(:section, title: "Sacadas", code: "SC", position: 1, category: category)

      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      render_click(lv, "enter_section", %{"section_id" => section.id})
      html = render_click(lv, "toggle_suggest", %{})

      assert has_element?(lv, "#collection-suggest-form")
      assert html =~ ~s(id="collection-suggest-section")

      assert has_element?(
               lv,
               "#collection-suggest-section option[selected][value='#{section.id}']"
             )
    end
  end

  describe "search" do
    test "displays steps matching the search term", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, name: "Base frontal")
      insert(:step, section: section, name: "Sacada simples")
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_change(lv, "search", %{"term" => "base"})
      assert html =~ "Base frontal"
      refute html =~ "Sacada simples"
    end

    test "search is case-insensitive", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, name: "Base frontal")
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_change(lv, "search", %{"term" => "BASE"})
      assert html =~ "Base frontal"
    end

    test "search with no results displays message", %{conn: conn} do
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_change(lv, "search", %{"term" => "xyzxyz"})
      assert html =~ "Nenhum resultado para"
    end

    test "empty search restores section view", %{conn: conn} do
      insert(:section, title: "Bases", position: 1)
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      render_change(lv, "search", %{"term" => "xpto"})
      html = render_change(lv, "search", %{"term" => ""})
      assert html =~ "Bases"
    end

    test "does not return wip steps in search", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, name: "Base rotativa", wip: true)
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_change(lv, "search", %{"term" => "rotativa"})
      refute html =~ "Base rotativa"
    end
  end

  describe "category filter" do
    test "displays only sections from the selected category", %{conn: conn} do
      cat_b = insert(:category, name: "bases", label: "Bases")
      cat_s = insert(:category, name: "sacadas", label: "Sacadas")
      insert(:section, title: "Seção Bases", position: 1, category: cat_b)
      section_s = insert(:section, title: "Seção Sacadas", position: 2, category: cat_s)
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_click(lv, "filter", %{"category" => "bases"})
      assert html =~ "Seção Bases"
      # "Seção Sacadas" text exists in suggest form dropdown, but section card should not show
      # Check that the toggle button for section_s doesn't exist
      refute html =~ "phx-value-section_id=\"#{section_s.id}\""
    end

    test "'all' filter restores all sections", %{conn: conn} do
      cat_b = insert(:category, name: "bases", label: "Bases")
      cat_s = insert(:category, name: "sacadas", label: "Sacadas")
      insert(:section, title: "Seção Bases", position: 1, category: cat_b)
      insert(:section, title: "Seção Sacadas", position: 2, category: cat_s)
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      render_click(lv, "filter", %{"category" => "bases"})
      html = render_click(lv, "filter", %{"category" => "all"})
      assert html =~ "Seção Bases"
      assert html =~ "Seção Sacadas"
    end
  end

  describe "expand and collapse sections" do
    test "expand_all displays steps from all sections", %{conn: conn} do
      section = insert(:section, title: "Bases", position: 1)
      insert(:step, section: section, name: "Base frontal")
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_click(lv, "expand_all", %{})
      assert html =~ "Base frontal"
    end

    test "collapse_all hides steps from sections", %{conn: conn} do
      section = insert(:section, title: "Bases", position: 1)
      insert(:step, section: section, name: "Base frontal")
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      render_click(lv, "expand_all", %{})
      html = render_click(lv, "collapse_all", %{})
      refute html =~ "Base frontal"
      assert html =~ "Bases"
    end

    test "toggle_section opens a specific section", %{conn: conn} do
      section = insert(:section, title: "Bases", position: 1)
      insert(:step, section: section, name: "Base frontal")
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_click(lv, "toggle_section", %{"section_id" => section.id})
      assert html =~ "Base frontal"
    end

    test "toggle_section closes an already open section", %{conn: conn} do
      section = insert(:section, title: "Bases", position: 1)
      insert(:step, section: section, name: "Base frontal")
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      render_click(lv, "toggle_section", %{"section_id" => section.id})
      html = render_click(lv, "toggle_section", %{"section_id" => section.id})
      refute html =~ "Base frontal"
    end
  end

  describe "drawer — step details" do
    test "opens drawer with step details on click", %{conn: conn} do
      section = insert(:section, title: "Bases", position: 1)
      insert(:step, section: section, code: "BF", name: "Base frontal", note: "Mechanical note")
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      render_click(lv, "expand_all", %{})
      html = render_click(lv, "open_step", %{"code" => "BF"})
      assert html =~ "Base frontal"
      assert html =~ "Mechanical note"
    end

    test "drawer keeps step actions in a fixed header above scrollable content", %{conn: conn} do
      section = insert(:section, title: "Bases", position: 1)
      insert(:step, section: section, code: "BF", name: "Base frontal", note: "Mechanical note")
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")

      html = render_click(lv, "open_step", %{"code" => "BF"})

      assert html =~ ~s(id="collection-drawer-header")
      assert html =~ ~s(id="collection-drawer-body")
      assert html =~ "flex flex-col overflow-hidden"
      assert html =~ "min-h-0 flex-1 overflow-y-auto p-6"
    end

    test "close_drawer hides the panel", %{conn: conn} do
      section = insert(:section, title: "Bases", position: 1)
      insert(:step, section: section, code: "BF", name: "Base frontal", note: "Test note")
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      render_click(lv, "open_step", %{"code" => "BF"})
      html = render_click(lv, "close_drawer", %{})
      refute html =~ "Test note"
    end

    test "shows outgoing connections in drawer", %{conn: conn} do
      section = insert(:section, title: "Bases", position: 1)
      step_a = insert(:step, section: section, code: "BF", name: "Base frontal")
      step_b = insert(:step, section: section, code: "SC", name: "Sacada simples")
      insert(:connection, source_step: step_a, target_step: step_b)
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_click(lv, "open_step", %{"code" => "BF"})
      assert html =~ "1 saídas"
      assert html =~ "SC"
    end

    test "regular user does not see edit button", %{conn: conn} do
      {:ok, _lv, html} = live(logged_in_conn(conn), ~p"/collection")
      refute html =~ "Editar"
    end
  end

  describe "drawer — admin editing" do
    defp admin_conn(conn) do
      admin = insert(:admin)
      log_in_user(conn, admin)
    end

    test "admin sees edit button", %{conn: conn} do
      {:ok, lv, html} = live(admin_conn(conn), ~p"/collection")

      assert html =~ "Editar"
      assert has_element?(lv, "#top-nav-edit-button")
    end

    test "admin updates step name via drawer", %{conn: conn} do
      section = insert(:section, title: "Bases", position: 1)
      insert(:step, section: section, code: "BF", name: "Base frontal")
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/collection")
      render_click(lv, "toggle_edit_mode", %{})
      render_click(lv, "open_step", %{"code" => "BF"})

      html =
        render_submit(lv, "update_step", %{
          "step" => %{"name" => "Base frontal v2", "code" => "BF"}
        })

      assert html =~ "Base frontal v2"
    end

    test "admin updates section title via drawer", %{conn: conn} do
      section = insert(:section, title: "Bases Antigas", position: 1)
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/collection")
      render_click(lv, "toggle_edit_mode", %{})
      render_click(lv, "open_section", %{"id" => section.id})

      html =
        render_submit(lv, "update_section", %{
          "section" => %{"title" => "Bases Novas", "position" => "1"}
        })

      assert html =~ "Bases Novas"
    end

    test "admin creates connection from drawer", %{conn: conn} do
      section = insert(:section, title: "Bases", position: 1)
      insert(:step, section: section, code: "BF", name: "Base frontal")
      insert(:step, section: section, code: "SC", name: "Sacada simples")
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/collection")
      render_click(lv, "toggle_edit_mode", %{})
      render_click(lv, "open_step", %{"code" => "BF"})
      render_submit(lv, "create_step_connection", %{"target_code" => "SC"})
      html = render_click(lv, "open_step", %{"code" => "BF"})
      assert html =~ "1 saídas"
    end

    test "admin deletes connection from drawer", %{conn: conn} do
      section = insert(:section, title: "Bases", position: 1)
      step_a = insert(:step, section: section, code: "BF", name: "Base frontal")
      step_b = insert(:step, section: section, code: "SC", name: "Sacada simples")
      insert(:connection, source_step: step_a, target_step: step_b)
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/collection")
      render_click(lv, "toggle_edit_mode", %{})
      render_click(lv, "open_step", %{"code" => "BF"})
      _html = render_click(lv, "delete_step_connection", %{"source" => "BF", "target" => "SC"})
      # Drawer refreshes — SC should no longer be in connections
      html = render_click(lv, "open_step", %{"code" => "BF"})
      assert html =~ "0 saídas"
    end

    test "admin creates new section", %{conn: conn} do
      cat = insert(:category, name: "bases", label: "Bases")
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/collection")
      render_click(lv, "toggle_edit_mode", %{})

      html =
        render_submit(lv, "create_section", %{
          "section" => %{"title" => "Nova Seção", "position" => "99", "category_id" => cat.id}
        })

      assert html =~ "Nova Seção"
    end

    test "admin creates new category", %{conn: conn} do
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/collection")
      render_click(lv, "toggle_edit_mode", %{})

      render_submit(lv, "create_category", %{
        "category" => %{"name" => "nova", "label" => "Nova Cat", "color" => "#ff0000"}
      })

      # Category appears in filter bar
      html = render(lv)
      assert html =~ "Nova Cat"
    end
  end

  describe "step suggestions" do
    test "user can suggest a new step with section", %{conn: conn} do
      cat = insert(:category, name: "bases", label: "Bases")
      section = insert(:section, title: "Bases", position: 1, category: cat)
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      render_click(lv, "toggle_suggest", %{})

      render_submit(lv, "create_suggested_step", %{
        "step" => %{
          "name" => "Meu passo",
          "code" => "MP-1",
          "category_id" => cat.id,
          "section_id" => section.id
        }
      })

      step = OGrupoDeEstudos.Repo.get_by(OGrupoDeEstudos.Encyclopedia.Step, code: "MP-1")
      assert step != nil
      assert step.section_id == section.id
      assert step.suggested_by_id != nil
    end

    test "suggested step appears in its section when expanded" do
      user = insert(:user)
      section = insert(:section, title: "Pescadas", position: 1)
      insert(:step, section: section, code: "PE-T", name: "Pescada teste", suggested_by: user)
      {:ok, lv, _html} = live(log_in_user(build_conn(), user), ~p"/collection")
      html = render_click(lv, "expand_all", %{})
      assert html =~ "Pescada teste"
      assert html =~ "Sugestão de"
    end

    test "suggested step shows badge in list" do
      user = insert(:user)
      section = insert(:section, title: "Bases", position: 1)
      insert(:step, section: section, code: "SUG-1", name: "Passo sugerido", suggested_by: user)
      {:ok, lv, _html} = live(log_in_user(build_conn(), user), ~p"/collection")
      html = render_click(lv, "expand_all", %{})
      assert html =~ "Sugestão de"
    end

    test "admin can approve a suggested step", %{conn: conn} do
      user = insert(:user)
      section = insert(:section, title: "Bases", position: 1)
      insert(:step, section: section, code: "SUG-2", name: "Passo sugerido", suggested_by: user)
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/collection")
      render_click(lv, "open_step", %{"code" => "SUG-2"})
      render_click(lv, "approve_step", %{"code" => "SUG-2"})
      # Step is now approved but keeps suggested_by_id
      step = OGrupoDeEstudos.Repo.get_by!(OGrupoDeEstudos.Encyclopedia.Step, code: "SUG-2")
      assert step.approved == true
      assert step.suggested_by_id == user.id
    end
  end

  describe "drawer overflow prevention" do
    test "drawer uses transform (not right: -Npx) when closed — prevents horizontal scroll", %{
      conn: conn
    } do
      {:ok, _view, html} = live(logged_in_conn(conn), ~p"/collection")

      # Drawer should NOT use negative right offset (which extends scroll width)
      refute html =~ "right: -400px",
             "drawer uses `right: -400px` which extends document scroll width; use transform: translateX(100%) instead"

      refute html =~ "right:-400px",
             "drawer uses `right:-400px` which extends document scroll width"

      # Drawer should use transform to position off-screen when closed
      assert html =~ "translateX(100%)",
             "drawer should use transform: translateX(100%) when closed for off-screen positioning"
    end
  end

  describe "step like in collection" do
    test "toggle_step_like likes a step", %{conn: conn} do
      user = insert(:user)
      step = insert(:step, section: insert(:section))
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/collection")
      view |> render_click("toggle_step_like", %{"id" => step.id})

      assert OGrupoDeEstudos.Engagement.liked?(user.id, "step", step.id)
    end
  end

  describe "drawer like and favorite" do
    test "toggle_drawer_like likes the drawer step", %{conn: conn} do
      user = insert(:user)
      step = insert(:step, section: insert(:section))
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/collection")
      view |> render_click("open_step", %{"code" => step.code})
      view |> render_click("toggle_drawer_like")

      assert OGrupoDeEstudos.Engagement.liked?(user.id, "step", step.id)
    end

    test "toggle_drawer_favorite favorites and auto-likes", %{conn: conn} do
      user = insert(:user)
      step = insert(:step, section: insert(:section))
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/collection")
      view |> render_click("open_step", %{"code" => step.code})
      view |> render_click("toggle_drawer_favorite")

      assert OGrupoDeEstudos.Engagement.favorited?(user.id, "step", step.id)
      assert OGrupoDeEstudos.Engagement.liked?(user.id, "step", step.id)
    end
  end
end
