defmodule OGrupoDeEstudosWeb.WorkshopFormWaitlistTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Workshops

  defp future_at(days) do
    DateTime.utc_now() |> DateTime.add(days, :day) |> DateTime.truncate(:second)
  end

  test "raising the capacity tells the organizer who left the waitlist", %{conn: conn} do
    owner = insert(:user, is_teacher: true)
    workshop = insert(:workshop, organizer: owner, capacity: 1, starts_at: future_at(7))
    {:ok, _} = Workshops.enroll(workshop, insert(:user))
    {:ok, _} = Workshops.join_waitlist(workshop, insert(:user))
    {:ok, _} = Workshops.join_waitlist(workshop, insert(:user))

    {:ok, lv, _html} =
      live(log_in_user(conn, owner), ~p"/study/workshops/#{workshop.slug}/edit")

    {:ok, conn} =
      lv
      |> form("#workshop-form", %{"workshop" => %{"capacity" => "3"}})
      |> render_submit(%{"publish" => "false"})
      |> follow_redirect(conn)

    assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "2 pessoas da lista de espera"
    assert Workshops.waitlist_count(workshop.id) == 0
  end

  test "saving without touching the capacity says nothing about the waitlist", %{conn: conn} do
    owner = insert(:user, is_teacher: true)
    workshop = insert(:workshop, organizer: owner, capacity: 1, starts_at: future_at(7))
    {:ok, _} = Workshops.enroll(workshop, insert(:user))
    {:ok, _} = Workshops.join_waitlist(workshop, insert(:user))

    {:ok, lv, _html} =
      live(log_in_user(conn, owner), ~p"/study/workshops/#{workshop.slug}/edit")

    {:ok, conn} =
      lv
      |> form("#workshop-form", %{"workshop" => %{"title" => "Novo título da aula"}})
      |> render_submit(%{"publish" => "false"})
      |> follow_redirect(conn)

    refute Phoenix.Flash.get(conn.assigns.flash, :info) =~ "avisad"
    assert Workshops.waitlist_count(workshop.id) == 1
  end
end
