defmodule ForrozinWeb.CollectionLiveTest do
  use ForrozinWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

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

    test "does not display wip steps when expanding the section", %{conn: conn} do
      section = insert(:section)
      insert(:step, section: section, name: "Base frontal", wip: false)
      insert(:step, section: section, name: "Sacada Suspensa", wip: true)
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_click(lv, "expand_all", %{})
      assert html =~ "Base frontal"
      refute html =~ "Sacada Suspensa"
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
      insert(:section, title: "Seção Sacadas", position: 2, category: cat_s)
      {:ok, lv, _html} = live(logged_in_conn(conn), ~p"/collection")
      html = render_click(lv, "filter", %{"category" => "bases"})
      assert html =~ "Seção Bases"
      refute html =~ "Seção Sacadas"
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
      {:ok, _lv, html} = live(admin_conn(conn), ~p"/collection")
      assert html =~ "Editar"
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

      step = Forrozin.Repo.get_by(Forrozin.Encyclopedia.Step, code: "MP-1")
      assert step != nil
      assert step.section_id == section.id
      assert step.suggested_by_id != nil
    end

    test "suggested step appears in its section when expanded", %{conn: conn} do
      user = insert(:user)
      section = insert(:section, title: "Pescadas", position: 1)
      insert(:step, section: section, code: "PE-T", name: "Pescada teste", suggested_by: user)
      {:ok, lv, _html} = live(log_in_user(build_conn(), user), ~p"/collection")
      html = render_click(lv, "expand_all", %{})
      assert html =~ "Pescada teste"
      assert html =~ "Sugestão de"
    end

    test "suggested step shows badge in list", %{conn: conn} do
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
      step = Forrozin.Repo.get_by!(Forrozin.Encyclopedia.Step, code: "SUG-2")
      assert step.approved == true
      assert step.suggested_by_id == user.id
    end
  end
end
