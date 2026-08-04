defmodule OGrupoDeEstudosWeb.StepSearchConsistencyTest do
  @moduledoc """
  Finding a step by code or by name, the same way everywhere it is asked for.

  The workshop page had its own hand-rolled copy of the search: a bare input with
  `phx-change`, which LiveView only fires inside a form. It looked exactly like the
  one that works and did nothing at all.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Brazil, Encyclopedia, Workshops}

  setup do
    organizer = insert(:user, is_teacher: true)

    {:ok, workshop} =
      Workshops.create_workshop(organizer, %{
        title: "Workshop de sacadas",
        description: "Conteúdo.",
        starts_at: Brazil.today() |> Date.add(7) |> DateTime.new!(~T[14:00:00], "Etc/UTC")
      })

    {:ok, workshop} = Workshops.publish_workshop(organizer, workshop)

    insert(:step, code: "IV", name: "Inversão base")
    insert(:step, code: "SCSP", name: "Sacada com sacada de perna")
    insert(:step, code: "WIP1", name: "Sacada secreta", wip: true)

    %{organizer: organizer, workshop: workshop}
  end

  defp open_workshop(conn, ctx),
    do: live(log_in_user(conn, ctx.organizer), ~p"/workshops/#{ctx.workshop.slug}")

  describe "the search on the workshop page" do
    test "the field lives inside a form, or phx-change never fires", %{conn: conn} = ctx do
      {:ok, _lv, html} = open_workshop(conn, ctx)

      assert html =~ ~s(phx-change="search_workshop_step")

      [_, between] =
        Regex.run(~r/<form[^>]*phx-change="search_workshop_step"[^>]*>(.*?)<\/form>/s, html)

      assert between =~ ~s(name="term")
    end

    test "typing a code offers the step", %{conn: conn} = ctx do
      {:ok, lv, _} = open_workshop(conn, ctx)

      html = render_change(lv, "search_workshop_step", %{"term" => "IV"})

      assert html =~ "Inversão base"
    end

    test "typing part of a name offers it too", %{conn: conn} = ctx do
      {:ok, lv, _} = open_workshop(conn, ctx)

      html = render_change(lv, "search_workshop_step", %{"term" => "sacada"})

      assert html =~ "Sacada com sacada de perna"
    end

    test "picking one links it to the class", %{conn: conn} = ctx do
      {:ok, lv, _} = open_workshop(conn, ctx)
      render_change(lv, "search_workshop_step", %{"term" => "IV"})
      step = Encyclopedia.get_step_by(code: "IV")

      render_click(lv, "add_workshop_step", %{"id" => step.id})

      assert [linked] = Workshops.list_steps(ctx.workshop.id)
      assert linked.code == "IV"
    end

    test "a step still being written is never offered", %{conn: conn} = ctx do
      {:ok, lv, _} = open_workshop(conn, ctx)

      html = render_change(lv, "search_workshop_step", %{"term" => "secreta"})

      refute html =~ "Sacada secreta"
    end

    test "an empty term offers nothing instead of the whole collection",
         %{conn: conn} = ctx do
      {:ok, lv, _} = open_workshop(conn, ctx)
      render_change(lv, "search_workshop_step", %{"term" => "sacada"})

      html = render_change(lv, "search_workshop_step", %{"term" => ""})

      refute html =~ "Sacada com sacada de perna"
    end
  end

  describe "the one search behind every surface" do
    test "blank asks nothing of the database" do
      assert Encyclopedia.search_steps("") == []
      assert Encyclopedia.search_steps("   ") == []
    end

    test "the same term gives the same steps to the diary and to the workshop" do
      assert Encyclopedia.search_steps("sacada") != []

      assert Enum.map(Encyclopedia.search_steps("sacada"), & &1.code) ==
               Enum.map(Encyclopedia.search_steps("sacada", limit: 8), & &1.code)
    end

    test "the limit is honoured, so a dropdown never runs off the screen" do
      for index <- 1..12, do: insert(:step, code: "GIR#{index}", name: "Giro número #{index}")

      assert length(Encyclopedia.search_steps("Giro", limit: 3)) == 3
    end

    test "a step still being written stays out, whoever asks" do
      refute Enum.any?(Encyclopedia.search_steps("secreta"), &(&1.code == "WIP1"))
    end
  end
end
