defmodule OGrupoDeEstudosWeb.InlineEditTest do
  @moduledoc """
  Fixing a field without leaving the page.

  Whoever organizes reads the published page far more often than the form, and
  most corrections are one field: a wrong hour, a missing number on the street.
  Going to the form, finding the field among twenty and coming back is the long
  way around for a two-second fix.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Brazil, Workshops}

  defp at_day(days) do
    Brazil.today()
    |> Date.add(days)
    |> DateTime.new!(Time.new!(14, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  setup do
    organizer = insert(:user, is_teacher: true)

    {:ok, workshop} =
      Workshops.create_workshop(organizer, %{
        title: "Workshop de sacadas",
        description: "Conteúdo do workshop.",
        location: "Telhado do Tatá",
        city: "Curitiba",
        state: "PR",
        starts_at: at_day(7)
      })

    {:ok, workshop} = Workshops.publish_workshop(organizer, workshop)

    {:ok, program} = Workshops.create_program(organizer, %{title: "Fim de semana"})
    {:ok, program} = Workshops.publish_program(organizer, program)

    %{organizer: organizer, workshop: workshop, program: program, outsider: insert(:user)}
  end

  defp open(conn, user, workshop),
    do: live(log_in_user(conn, user), ~p"/workshops/#{workshop.slug}")

  describe "who gets the pencil" do
    test "whoever organizes sees one next to the fields", %{conn: conn} = ctx do
      {:ok, _lv, html} = open(conn, ctx.organizer, ctx.workshop)

      assert html =~ ~s(phx-click="edit_field")
      assert html =~ "Editar título"
    end

    test "whoever only attends sees none", %{conn: conn} = ctx do
      {:ok, _lv, html} = open(conn, ctx.outsider, ctx.workshop)

      refute html =~ ~s(phx-click="edit_field")
    end

    test "a visitor with no account sees none", %{conn: conn} = ctx do
      {:ok, _lv, html} = live(conn, ~p"/workshops/#{ctx.workshop.slug}")

      refute html =~ ~s(phx-click="edit_field")
    end
  end

  describe "editing in place" do
    test "the pencil turns the title into a field", %{conn: conn} = ctx do
      {:ok, lv, _} = open(conn, ctx.organizer, ctx.workshop)

      html = render_click(lv, "edit_field", %{"field" => "title"})

      assert html =~ ~s(name="value")
      assert html =~ "Workshop de sacadas"
    end

    test "saving writes only that field", %{conn: conn} = ctx do
      {:ok, lv, _} = open(conn, ctx.organizer, ctx.workshop)
      render_click(lv, "edit_field", %{"field" => "title"})

      html = render_submit(lv, "save_field", %{"value" => "Workshop de sacadas avançado"})

      updated = Workshops.get_by_slug(ctx.workshop.slug)
      assert updated.title == "Workshop de sacadas avançado"
      assert updated.description == "Conteúdo do workshop."
      assert html =~ "Workshop de sacadas avançado"
    end

    test "cancelling leaves the field as it was", %{conn: conn} = ctx do
      {:ok, lv, _} = open(conn, ctx.organizer, ctx.workshop)
      render_click(lv, "edit_field", %{"field" => "title"})

      html = render_click(lv, "cancel_edit", %{})

      refute html =~ ~s(name="value")
      assert Workshops.get_by_slug(ctx.workshop.slug).title == "Workshop de sacadas"
    end

    test "only one field opens at a time", %{conn: conn} = ctx do
      {:ok, lv, _} = open(conn, ctx.organizer, ctx.workshop)
      render_click(lv, "edit_field", %{"field" => "title"})

      html = render_click(lv, "edit_field", %{"field" => "description"})

      assert [_only_one] = Regex.scan(~r/name="value"/, html)
    end

    test "an empty title is refused, and says why", %{conn: conn} = ctx do
      {:ok, lv, _} = open(conn, ctx.organizer, ctx.workshop)
      render_click(lv, "edit_field", %{"field" => "title"})

      html = render_submit(lv, "save_field", %{"value" => ""})

      assert html =~ "não pode ficar"
      assert Workshops.get_by_slug(ctx.workshop.slug).title == "Workshop de sacadas"
    end

    test "a field nobody offered is ignored instead of written", %{conn: conn} = ctx do
      {:ok, lv, _} = open(conn, ctx.organizer, ctx.workshop)

      render_click(lv, "edit_field", %{"field" => "slug"})
      render_submit(lv, "save_field", %{"value" => "roubado"})

      assert Workshops.get_by_slug(ctx.workshop.slug)
    end

    test "whoever only attends writes nothing by sending the event", %{conn: conn} = ctx do
      {:ok, lv, _} = open(conn, ctx.outsider, ctx.workshop)

      render_click(lv, "edit_field", %{"field" => "title"})
      render_submit(lv, "save_field", %{"value" => "invadido"})

      assert Workshops.get_by_slug(ctx.workshop.slug).title == "Workshop de sacadas"
    end
  end

  describe "the address, which is several fields at once" do
    test "the pencil opens the whole block", %{conn: conn} = ctx do
      {:ok, lv, _} = open(conn, ctx.organizer, ctx.workshop)

      html = render_click(lv, "edit_field", %{"field" => "address"})

      assert html =~ ~s(name="street")
      assert html =~ ~s(name="city")
      assert html =~ ~s(name="postal_code")
    end

    test "saving writes the parts together", %{conn: conn} = ctx do
      {:ok, lv, _} = open(conn, ctx.organizer, ctx.workshop)
      render_click(lv, "edit_field", %{"field" => "address"})

      render_submit(lv, "save_field", %{
        "street" => "R. Dr. Alexandre Gutierrez",
        "street_number" => "480",
        "neighborhood" => "Água Verde",
        "city" => "Curitiba",
        "state" => "PR",
        "postal_code" => "80240-090"
      })

      updated = Workshops.get_by_slug(ctx.workshop.slug)
      assert updated.street == "R. Dr. Alexandre Gutierrez"
      assert updated.street_number == "480"
      assert updated.city == "Curitiba"
    end
  end

  describe "when it was last touched" do
    test "the page says it, for whoever organizes", %{conn: conn} = ctx do
      {:ok, _lv, html} = open(conn, ctx.organizer, ctx.workshop)

      assert html =~ "Última atualização"
      assert html =~ Brazil.format_datetime_full(ctx.workshop.updated_at)
    end

    test "editing moves the stamp", %{conn: conn} = ctx do
      {:ok, lv, _} = open(conn, ctx.organizer, ctx.workshop)
      render_click(lv, "edit_field", %{"field" => "title"})

      render_submit(lv, "save_field", %{"value" => "Outro nome"})

      updated = Workshops.get_by_slug(ctx.workshop.slug)
      assert DateTime.compare(updated.updated_at, ctx.workshop.updated_at) == :gt
    end
  end

  describe "the same on a program" do
    defp open_program(conn, user, program),
      do: live(log_in_user(conn, user), ~p"/programs/#{program.slug}")

    test "whoever owns it gets the pencil", %{conn: conn} = ctx do
      {:ok, _lv, html} = open_program(conn, ctx.organizer, ctx.program)

      assert html =~ ~s(phx-click="edit_field")
    end

    test "whoever only reads does not", %{conn: conn} = ctx do
      {:ok, _lv, html} = open_program(conn, ctx.outsider, ctx.program)

      refute html =~ ~s(phx-click="edit_field")
    end

    test "saving a field writes it", %{conn: conn} = ctx do
      {:ok, lv, _} = open_program(conn, ctx.organizer, ctx.program)
      render_click(lv, "edit_field", %{"field" => "title"})

      render_submit(lv, "save_field", %{"value" => "Fim de semana de forró roots"})

      assert Workshops.get_program_by_slug(ctx.program.slug).title ==
               "Fim de semana de forró roots"
    end

    test "the page says when it was last touched", %{conn: conn} = ctx do
      {:ok, _lv, html} = open_program(conn, ctx.organizer, ctx.program)

      assert html =~ "Última atualização"
    end
  end
end
