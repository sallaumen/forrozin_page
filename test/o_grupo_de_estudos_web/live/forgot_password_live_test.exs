defmodule OGrupoDeEstudosWeb.ForgotPasswordLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  describe "mount" do
    test "renders the recovery form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/forgot-password")

      assert html =~ "Recuperar senha"
      assert html =~ "Enviaremos um link"
    end
  end

  describe "submit" do
    test "sends the reset email for a registered address", %{conn: conn} do
      user = insert(:user)
      {:ok, lv, _html} = live(conn, ~p"/forgot-password")

      html = render_submit(lv, "submit", %{"email" => user.email})

      assert html =~ "você vai receber um link"
      assert_email_sent(to: [{user.name, user.email}])
    end

    test "shows the same message for an unknown address, without email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/forgot-password")

      html = render_submit(lv, "submit", %{"email" => "ninguem@example.com"})

      assert html =~ "você vai receber um link"
      refute_email_sent()
    end
  end
end
