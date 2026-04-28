defmodule OGrupoDeEstudosWeb.StudyInviteLiveTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Study

  describe "invite page" do
    test "shows the teacher profile and the join CTA", %{conn: conn} do
      teacher =
        insert(:user,
          is_teacher: true,
          invite_slug: "prof-lia",
          bio: "Forró roots em Curitiba",
          city: "Curitiba",
          state: "PR"
        )

      {:ok, _lv, html} = live(conn, ~p"/study/invite/#{teacher.invite_slug}")

      assert html =~ teacher.name
      assert html =~ "@#{teacher.username}"
      assert html =~ "Forró roots em Curitiba"
      assert html =~ "Quero estudar com"
    end

    test "logged in user can accept the teacher invite from the page", %{conn: conn} do
      teacher = insert(:user, is_teacher: true, invite_slug: "prof-joana")
      student = insert(:user)
      conn = log_in_user(conn, student)

      {:ok, lv, _html} = live(conn, ~p"/study/invite/#{teacher.invite_slug}")

      assert lv
             |> element("#study-invite-accept")
             |> render_click()

      # accept_invite now creates a pending link; teacher must approve before it becomes active
      pending = Study.list_pending_requests_for_teacher(teacher.id)
      assert Enum.any?(pending, &(&1.student_id == student.id))
    end
  end
end
