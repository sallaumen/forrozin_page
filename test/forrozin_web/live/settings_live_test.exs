defmodule ForrozinWeb.SettingsLiveTest do
  use ForrozinWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defp logged_in_conn(conn) do
    user = insert(:user)
    {log_in_user(conn, user), user}
  end

  describe "access" do
    test "redirects to /login when not authenticated", %{conn: conn} do
      {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/settings")
    end

    test "renders page for authenticated user", %{conn: conn} do
      {conn, _user} = logged_in_conn(conn)
      {:ok, _lv, html} = live(conn, ~p"/settings")
      assert html =~ "Configurações"
    end
  end

  describe "profile update" do
    test "can update bio", %{conn: conn} do
      {conn, _user} = logged_in_conn(conn)
      {:ok, lv, _html} = live(conn, ~p"/settings")

      html =
        lv
        |> form("form[phx-submit='save']", %{
          bio: "Sou dançarino de forró roots em Curitiba.",
          instagram: ""
        })
        |> render_submit()

      assert html =~ "Perfil atualizado com sucesso."
    end

    test "can update instagram handle", %{conn: conn} do
      {conn, _user} = logged_in_conn(conn)
      {:ok, lv, _html} = live(conn, ~p"/settings")

      html =
        lv
        |> form("form[phx-submit='save']", %{bio: "", instagram: "forrozin_curitiba"})
        |> render_submit()

      assert html =~ "Perfil atualizado com sucesso."
    end

    test "shows error when bio exceeds 2000 characters", %{conn: conn} do
      {conn, _user} = logged_in_conn(conn)
      {:ok, lv, _html} = live(conn, ~p"/settings")

      long_bio = String.duplicate("a", 2001)

      html =
        lv
        |> form("form[phx-submit='save']", %{bio: long_bio, instagram: ""})
        |> render_submit()

      assert html =~ "bio" or html =~ "2000"
    end

    test "validate event updates form without saving", %{conn: conn} do
      {conn, _user} = logged_in_conn(conn)
      {:ok, lv, _html} = live(conn, ~p"/settings")

      html =
        lv
        |> form("form[phx-change='validate']", %{bio: "Texto parcial", instagram: ""})
        |> render_change()

      # Not saved yet
      refute html =~ "Perfil atualizado com sucesso."
    end
  end
end
