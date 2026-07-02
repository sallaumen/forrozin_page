defmodule OGrupoDeEstudosWeb.ResetPasswordLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Accounts

  defp reset_token(user) do
    Phoenix.Token.sign(OGrupoDeEstudosWeb.Endpoint, "reset_password", user.id)
  end

  describe "mount" do
    test "renders the form for a valid token", %{conn: conn} do
      user = insert(:user)

      {:ok, _lv, html} = live(conn, ~p"/reset-password/#{reset_token(user)}")

      assert html =~ "Nova senha"
    end

    test "redirects to forgot-password for an invalid token", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/forgot-password"}}} =
               live(conn, ~p"/reset-password/token-invalido")
    end
  end

  describe "reset" do
    test "rejects a short password", %{conn: conn} do
      user = insert(:user)
      {:ok, lv, _html} = live(conn, ~p"/reset-password/#{reset_token(user)}")

      html =
        render_submit(lv, "reset", %{"password" => "curta", "password_confirmation" => "curta"})

      assert html =~ "pelo menos 8 caracteres"
    end

    test "rejects mismatched confirmation", %{conn: conn} do
      user = insert(:user)
      {:ok, lv, _html} = live(conn, ~p"/reset-password/#{reset_token(user)}")

      html =
        render_submit(lv, "reset", %{
          "password" => "senhanova123",
          "password_confirmation" => "outracoisa123"
        })

      assert html =~ "As senhas não batem"
    end

    test "updates the password and redirects to login", %{conn: conn} do
      user = insert(:user)
      {:ok, lv, _html} = live(conn, ~p"/reset-password/#{reset_token(user)}")

      result =
        render_submit(lv, "reset", %{
          "password" => "senhanova123",
          "password_confirmation" => "senhanova123"
        })

      assert {:error, {:redirect, %{to: "/login"}}} = result

      reloaded = Accounts.get_user_by_id(user.id)
      assert reloaded.password_hash != user.password_hash
      assert Argon2.verify_pass("senhanova123", reloaded.password_hash)
    end
  end
end
