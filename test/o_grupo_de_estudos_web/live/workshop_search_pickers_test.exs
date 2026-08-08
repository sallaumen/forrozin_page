defmodule OGrupoDeEstudosWeb.WorkshopSearchPickersTest do
  @moduledoc """
  The two workshop pickers suggest while typing, in the same standard
  shape the study area already uses: nobody needs to know a full name.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Workshops

  defp future_at(days) do
    DateTime.utc_now() |> DateTime.add(days, :day) |> DateTime.truncate(:second)
  end

  describe "linking steps on the workshop page" do
    test "typing shows step previews and picking one links it", %{conn: conn} do
      owner = insert(:user)
      workshop = insert(:workshop, organizer: owner, starts_at: future_at(7))
      step = insert(:step, name: "Sacada Alta")

      {:ok, lv, _html} = live(log_in_user(conn, owner), ~p"/workshops/#{workshop.slug}")

      html =
        lv
        |> element("#workshop-step-search form")
        |> render_change(%{"term" => "sacada"})

      assert html =~ "Sacada Alta"

      lv
      |> element(~s(#workshop-step-search button[phx-value-id="#{step.id}"]))
      |> render_click()

      assert Enum.any?(Workshops.list_steps(workshop.id), &(&1.name == "Sacada Alta"))
    end
  end

  describe "adding an organizer on the manage page" do
    test "typing shows people previews and picking one promotes them", %{conn: conn} do
      owner = insert(:user)
      workshop = insert(:workshop, organizer: owner, starts_at: future_at(7))
      partner = insert(:user, name: "Maria Panorama")

      {:ok, lv, _html} = live(log_in_user(conn, owner), ~p"/workshops/#{workshop.slug}/manage")

      html =
        lv
        |> element("#admin-user-search form")
        |> render_change(%{"username" => "panorama"})

      assert html =~ "Maria Panorama"

      lv
      |> element(~s(#admin-user-search button[phx-value-username="#{partner.username}"]))
      |> render_click()

      admin_ids = workshop |> Workshops.list_co_admins() |> Enum.map(& &1.user_id)
      assert partner.id in admin_ids
    end

    test "people already organizing stay out of the previews", %{conn: conn} do
      owner = insert(:user, name: "Dono Panorama")
      workshop = insert(:workshop, organizer: owner, starts_at: future_at(7))

      {:ok, lv, _html} = live(log_in_user(conn, owner), ~p"/workshops/#{workshop.slug}/manage")

      html =
        lv
        |> element("#admin-user-search form")
        |> render_change(%{"username" => "panorama"})

      refute html =~ ~s(phx-value-username="#{owner.username}")
    end
  end
end
