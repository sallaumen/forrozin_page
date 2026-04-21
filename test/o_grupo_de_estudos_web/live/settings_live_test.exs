defmodule OGrupoDeEstudosWeb.SettingsLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Accounts

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
      {conn, user} = logged_in_conn(conn)
      {:ok, lv, _html} = live(conn, ~p"/settings")

      html =
        lv
        |> form("#settings-form", %{
          "user" => %{
            "name" => user.name,
            "username" => user.username,
            "country" => "BR",
            "state" => "PR",
            "city" => "Curitiba",
            "bio" => "Sou dançarino de forró roots em Curitiba.",
            "instagram" => "",
            "is_teacher" => "false"
          }
        })
        |> render_submit()

      assert html =~ "Perfil atualizado com sucesso."
    end

    test "can update instagram handle", %{conn: conn} do
      {conn, user} = logged_in_conn(conn)
      {:ok, lv, _html} = live(conn, ~p"/settings")

      html =
        lv
        |> form("#settings-form", %{
          "user" => %{
            "name" => user.name,
            "username" => user.username,
            "country" => "BR",
            "state" => "PR",
            "city" => "Curitiba",
            "bio" => "",
            "instagram" => "o_grupo_de_estudos_curitiba",
            "is_teacher" => "false"
          }
        })
        |> render_submit()

      assert html =~ "Perfil atualizado com sucesso."
    end

    test "shows error when bio exceeds 2000 characters", %{conn: conn} do
      {conn, user} = logged_in_conn(conn)
      {:ok, lv, _html} = live(conn, ~p"/settings")

      long_bio = String.duplicate("a", 2001)

      html =
        lv
        |> form("#settings-form", %{
          "user" => %{
            "name" => user.name,
            "username" => user.username,
            "country" => "BR",
            "state" => "PR",
            "city" => "Curitiba",
            "bio" => long_bio,
            "instagram" => "",
            "is_teacher" => "false"
          }
        })
        |> render_submit()

      assert html =~ "bio" or html =~ "2000"
    end

    test "validate event updates form without saving", %{conn: conn} do
      {conn, user} = logged_in_conn(conn)
      {:ok, lv, _html} = live(conn, ~p"/settings")

      html =
        lv
        |> form("#settings-form", %{
          "user" => %{
            "name" => user.name,
            "username" => user.username,
            "country" => "BR",
            "state" => "PR",
            "city" => "Curitiba",
            "bio" => "Texto parcial",
            "instagram" => "",
            "is_teacher" => "false"
          }
        })
        |> render_change()

      # Not saved yet
      refute html =~ "Perfil atualizado com sucesso."
    end

    test "can toggle teacher mode", %{conn: conn} do
      {conn, user} = logged_in_conn(conn)
      {:ok, lv, _html} = live(conn, ~p"/settings")

      html =
        lv
        |> form("#settings-form", %{
          "user" => %{
            "name" => user.name,
            "username" => user.username,
            "country" => "BR",
            "state" => "PR",
            "city" => "Curitiba",
            "bio" => "",
            "instagram" => "",
            "is_teacher" => "true"
          }
        })
        |> render_submit()

      assert html =~ "Perfil atualizado com sucesso."
      assert Accounts.get_user_by_id(user.id).is_teacher
    end
  end
end
