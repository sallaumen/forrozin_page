defmodule OGrupoDeEstudosWeb.UserRegistrationLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Accounts
  alias OGrupoDeEstudos.Study

  describe "signup page" do
    test "renders form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/signup")
      assert html =~ "Criar conta"
      assert html =~ "Usuário"
      assert html =~ "Senha"
    end

    test "redirects to /collection when already authenticated", %{conn: conn} do
      user = insert(:user)
      conn = conn |> log_in_user(user)

      assert {:error, {:redirect, %{to: "/collection"}}} = live(conn, ~p"/signup")
    end
  end

  describe "user registration" do
    test "creates account and auto-logs in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/signup")

      result =
        lv
        |> form("form",
          user: %{
            username: "novousuario",
            name: "Novo Usuário",
            email: "novo@example.com",
            password: "senhasegura123",
            country: "BR",
            state: "PR",
            city: "Curitiba"
          }
        )
        |> render_submit()

      # Redirects to auto-login endpoint
      assert {:error, {:redirect, %{to: "/auto-login/" <> _user_id}}} = result
    end

    test "creates account with the teacher flag enabled", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/signup")

      result =
        lv
        |> form("#registration-form",
          user: %{
            username: "profmaria",
            name: "Maria Professora",
            email: "maria@example.com",
            password: "senhasegura123",
            country: "BR",
            state: "PR",
            city: "Curitiba",
            is_teacher: "true"
          }
        )
        |> render_submit()

      assert {:error, {:redirect, %{to: "/auto-login/" <> _user_id}}} = result
      assert Accounts.get_user_by_username("profmaria").is_teacher
    end

    test "accepts a teacher invite after signup", %{conn: conn} do
      teacher = insert(:user, is_teacher: true, invite_slug: "prof-joana")
      {:ok, lv, _html} = live(conn, ~p"/signup?teacher_invite=#{teacher.invite_slug}")

      result =
        lv
        |> form("#registration-form",
          user: %{
            username: "alunaana",
            name: "Ana Aluna",
            email: "ana@example.com",
            password: "senhasegura123",
            country: "BR",
            state: "PR",
            city: "Curitiba"
          }
        )
        |> render_submit()

      assert {:error, {:redirect, %{to: "/auto-login/" <> _user_id}}} = result

      student = Accounts.get_user_by_username("alunaana")
      assert Enum.any?(Study.list_teachers_for_student(student.id), &(&1.id == teacher.id))
    end

    test "displays errors with invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/signup")

      html =
        lv
        |> form("form", user: %{username: "ab", email: "invalido", password: "curta"})
        |> render_submit()

      assert html =~ "should be at least"
    end
  end
end
