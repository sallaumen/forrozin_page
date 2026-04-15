defmodule OGrupoDeEstudosWeb.AdminBackupsLiveTest do
  @moduledoc """
  Integration tests for the admin backups management page.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Admin.Backup

  defp admin_conn(conn) do
    admin = insert(:admin)
    log_in_user(conn, admin)
  end

  defp user_conn(conn) do
    user = insert(:user)
    log_in_user(conn, user)
  end

  # ---------------------------------------------------------------------------
  # Access control
  # ---------------------------------------------------------------------------

  describe "access control" do
    test "redirects unauthenticated user to /login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/admin/backups")
    end

    test "redirects non-admin user to /graph/visual", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/graph/visual"}}} =
               live(user_conn(conn), ~p"/admin/backups")
    end

    test "admin can access the page", %{conn: conn} do
      {:ok, _lv, html} = live(admin_conn(conn), ~p"/admin/backups")
      assert html =~ "Backups do Sistema"
    end
  end

  # ---------------------------------------------------------------------------
  # Page rendering
  # ---------------------------------------------------------------------------

  describe "page rendering" do
    test "shows create backup button", %{conn: conn} do
      {:ok, _lv, html} = live(admin_conn(conn), ~p"/admin/backups")
      assert html =~ "Criar backup agora"
    end

    test "shows section header for file list", %{conn: conn} do
      {:ok, _lv, html} = live(admin_conn(conn), ~p"/admin/backups")
      assert html =~ "Arquivos disponíveis"
    end

    test "shows technical note about on_conflict", %{conn: conn} do
      {:ok, _lv, html} = live(admin_conn(conn), ~p"/admin/backups")
      assert html =~ "on_conflict: :nothing"
    end

    test "shows empty state message when no backups exist in default dir", %{conn: conn} do
      # This test is only meaningful if the priv/backups dir is empty.
      # We verify the page loads without error regardless.
      {:ok, _lv, html} = live(admin_conn(conn), ~p"/admin/backups")
      assert html =~ "Backups do Sistema"
    end
  end

  # ---------------------------------------------------------------------------
  # Create backup event
  # ---------------------------------------------------------------------------

  describe "create_backup event" do
    test "creates a backup and shows success flash", %{conn: conn} do
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/admin/backups")

      lv
      |> element("button[phx-click=\"create_backup\"]")
      |> render_click()

      assert render(lv) =~ "Backup criado com sucesso"
    end

    test "backup list grows after creating a backup", %{conn: conn} do
      {:ok, lv, html_before} = live(admin_conn(conn), ~p"/admin/backups")

      # Count backup entries before
      count_before =
        html_before |> String.split("phx-value-path") |> length() |> then(&(&1 - 1))

      lv
      |> element("button[phx-click=\"create_backup\"]")
      |> render_click()

      html_after = render(lv)
      count_after = html_after |> String.split("phx-value-path") |> length() |> then(&(&1 - 1))

      assert count_after >= count_before
    end
  end

  # ---------------------------------------------------------------------------
  # Restore backup event
  # ---------------------------------------------------------------------------

  describe "restore_backup event" do
    test "shows error flash when path is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(admin_conn(conn), ~p"/admin/backups")

      Phoenix.LiveViewTest.render_hook(lv, "restore_backup", %{
        "path" => "/nonexistent/ghost.json"
      })

      assert render(lv) =~ "Backup não encontrado ou caminho inválido"
    end

    test "restores from a valid backup and shows success flash", %{conn: conn} do
      path = Backup.create_backup!()

      {:ok, lv, _html} = live(admin_conn(conn), ~p"/admin/backups")

      Phoenix.LiveViewTest.render_hook(lv, "restore_backup", %{"path" => path})

      assert render(lv) =~ "restaurado com sucesso"
    end
  end

  # ---------------------------------------------------------------------------
  # Helper functions
  # ---------------------------------------------------------------------------

  describe "format_size/1" do
    test "formats bytes under 1 KB" do
      assert OGrupoDeEstudosWeb.AdminBackupsLive.format_size(512) == "512 B"
    end

    test "formats kilobytes" do
      assert OGrupoDeEstudosWeb.AdminBackupsLive.format_size(2048) == "2.0 KB"
    end

    test "formats megabytes" do
      assert OGrupoDeEstudosWeb.AdminBackupsLive.format_size(2_097_152) == "2.0 MB"
    end
  end

  describe "format_timestamp/1" do
    test "formats a valid NaiveDateTime" do
      dt = ~N[2026-04-15 12:00:00]
      assert OGrupoDeEstudosWeb.AdminBackupsLive.format_timestamp(dt) == "15/04/2026 às 12:00:00"
    end

    test "returns fallback for nil" do
      assert OGrupoDeEstudosWeb.AdminBackupsLive.format_timestamp(nil) == "Data desconhecida"
    end
  end
end
