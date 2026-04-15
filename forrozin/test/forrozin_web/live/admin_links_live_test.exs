defmodule ForrozinWeb.AdminLinksLiveTest do
  use ForrozinWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defp admin_conn(conn) do
    admin = insert(:admin)
    log_in_user(conn, admin)
  end

  defp user_conn(conn) do
    user = insert(:user)
    log_in_user(conn, user)
  end

  describe "access control" do
    test "redirects non-admin user to /collection", %{conn: conn} do
      {:error, {:redirect, %{to: "/collection"}}} =
        live(user_conn(conn), ~p"/admin/links")
    end

    test "redirects unauthenticated user to /login", %{conn: conn} do
      {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/admin/links")
    end
  end

  describe "admin sees pending links" do
    test "shows pending links with approve and delete buttons", %{conn: conn} do
      step = insert(:step, code: "BF", name: "Base Frontal")
      submitter = insert(:user)

      _pending =
        insert(:step_link,
          step: step,
          submitted_by: submitter,
          approved: false,
          title: "Vídeo do BF"
        )

      {:ok, _lv, html} = live(admin_conn(conn), ~p"/admin/links")

      assert html =~ "Vídeo do BF"
      assert html =~ "BF"
      assert html =~ "Aprovar"
      assert html =~ "Deletar"
    end

    test "does not show approved links in pending section", %{conn: conn} do
      step = insert(:step, code: "SC", name: "Saidinha")
      submitter = insert(:user)

      insert(:step_link,
        step: step,
        submitted_by: submitter,
        approved: true,
        title: "Link aprovado"
      )

      {:ok, _lv, html} = live(admin_conn(conn), ~p"/admin/links")

      # Link aprovado goes to the approved section, not pending section
      # The page renders "0 pendentes" in the pending count
      assert html =~ "Pendentes (0)"
    end
  end

  describe "admin approves a link" do
    test "approves a pending link and moves it to approved section", %{conn: conn} do
      step = insert(:step, code: "TR", name: "Trava")
      submitter = insert(:user)

      pending =
        insert(:step_link, step: step, submitted_by: submitter, approved: false, title: "Link TR")

      {:ok, lv, _html} = live(admin_conn(conn), ~p"/admin/links")

      lv
      |> element("button[phx-value-id=\"#{pending.id}\"]", "Aprovar")
      |> render_click()

      html = render(lv)
      assert html =~ "Pendentes (0)"
      assert html =~ "Aprovados (1)"
    end
  end

  describe "admin deletes a link" do
    test "soft-deletes a pending link and removes it from view", %{conn: conn} do
      step = insert(:step, code: "GP", name: "Giro Paulista")
      submitter = insert(:user)

      pending =
        insert(:step_link, step: step, submitted_by: submitter, approved: false, title: "Link GP")

      {:ok, lv, _html} = live(admin_conn(conn), ~p"/admin/links")

      html_before = render(lv)
      assert html_before =~ "Link GP"

      lv
      |> element("[phx-click=\"delete_link\"][phx-value-id=\"#{pending.id}\"]")
      |> render_click()

      html_after = render(lv)
      refute html_after =~ "Link GP"
    end

    test "soft-deletes an approved link", %{conn: conn} do
      step = insert(:step, code: "IV", name: "Inversão")
      submitter = insert(:user)

      approved =
        insert(:step_link, step: step, submitted_by: submitter, approved: true, title: "Link IV")

      {:ok, lv, _html} = live(admin_conn(conn), ~p"/admin/links")

      html_before = render(lv)
      assert html_before =~ "Link IV"

      lv
      |> element("[phx-click=\"delete_link\"][phx-value-id=\"#{approved.id}\"]")
      |> render_click()

      html_after = render(lv)
      refute html_after =~ "Link IV"
    end
  end
end
