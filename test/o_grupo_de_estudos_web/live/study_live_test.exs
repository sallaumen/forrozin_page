defmodule OGrupoDeEstudosWeb.StudyLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Study

  describe "access" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/study")
    end
  end

  describe "study home" do
    test "shows study overview and diary section for authenticated user", %{conn: conn} do
      user = insert(:user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/study")

      assert html =~ "Estudos"
      assert html =~ "Meu diário"
      assert html =~ "Meus professores"
      assert html =~ "Você ainda não registrou seu estudo de hoje."
    end

    test "shows linked teachers and students", %{conn: conn} do
      teacher = insert(:user, is_teacher: true)
      student = insert(:user)
      {:ok, link} = Study.accept_invite(student, teacher.invite_slug)
      conn = log_in_user(conn, teacher)

      {:ok, _lv, html} = live(conn, ~p"/study")

      assert html =~ "Meus alunos"
      assert html =~ student.name
      assert html =~ "/study/shared/#{link.id}"
    end
  end
end
