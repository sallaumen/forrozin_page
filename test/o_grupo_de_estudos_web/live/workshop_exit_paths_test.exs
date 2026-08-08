defmodule OGrupoDeEstudosWeb.WorkshopExitPathsTest do
  @moduledoc """
  Nobody stays stuck: whoever waits can leave the line, whoever enrolled
  can cancel, and both can come back at will.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Workshops

  defp future_at(days) do
    DateTime.utc_now() |> DateTime.add(days, :day) |> DateTime.truncate(:second)
  end

  test "a waiting person sees the leave button, leaves and can come back", %{conn: conn} do
    owner = insert(:user)
    workshop = insert(:workshop, organizer: owner, capacity: 1, starts_at: future_at(7))
    {:ok, _} = Workshops.enroll(workshop, insert(:user))
    student = insert(:user)

    {:ok, lv, _html} = live(log_in_user(conn, student), ~p"/workshops/#{workshop.slug}")

    html = render_click(lv, "join_waitlist", %{})
    assert html =~ "lista de espera"
    assert has_element?(lv, "button", "sair da lista")
    assert Workshops.waitlist_count(workshop.id) == 1

    html = render_click(lv, "leave_waitlist", %{})
    assert html =~ "Entrar na lista de espera"
    assert Workshops.waitlist_count(workshop.id) == 0

    render_click(lv, "join_waitlist", %{})
    assert Workshops.waitlist_count(workshop.id) == 1
  end

  test "an enrolled person sees the cancel button, cancels and can come back", %{conn: conn} do
    owner = insert(:user)
    workshop = insert(:workshop, organizer: owner, starts_at: future_at(7))
    student = insert(:user)

    {:ok, lv, _html} = live(log_in_user(conn, student), ~p"/workshops/#{workshop.slug}")

    render_click(lv, "enroll", %{})
    assert has_element?(lv, ~s(button[phx-click="cancel_enrollment"]))
    assert Workshops.count_enrollments(workshop.id) == 1

    html = render_click(lv, "cancel_enrollment", %{})
    assert html =~ "Fazer inscrição"
    assert Workshops.count_enrollments(workshop.id) == 0

    render_click(lv, "enroll", %{})
    assert Workshops.count_enrollments(workshop.id) == 1
  end
end
