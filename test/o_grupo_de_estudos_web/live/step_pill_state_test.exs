defmodule OGrupoDeEstudosWeb.StepPillStateTest do
  @moduledoc """
  A step chip tells by color whether the user already knows the step. The
  sheet opened from a chip carries the same color, since it is that chip
  opened.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Engagement, Study, Workshops}

  setup do
    student = insert(:user)
    known_step = insert(:step, code: "IV", name: "Inversão base")
    unknown_step = insert(:step, code: "SC", name: "Sacada simples")

    {:ok, :learned} = Engagement.toggle_learned(student.id, known_step.id)

    %{student: student, known_step: known_step, unknown_step: unknown_step}
  end

  describe "in the diary" do
    setup ctx do
      {:ok, _} =
        Study.upsert_personal_note(ctx.student, Date.utc_today(), %{
          content: "Aula de hoje.",
          step_ids: [ctx.known_step.id, ctx.unknown_step.id]
        })

      ctx
    end

    test "step the user already knows comes green", ctx do
      {:ok, _lv, html} = live(log_in_user(build_conn(), ctx.student), ~p"/study")

      assert chip_de(html, "IV") =~ "accent-green"
    end

    test "step the user does not know yet stays amber", ctx do
      {:ok, _lv, html} = live(log_in_user(build_conn(), ctx.student), ~p"/study")

      assert chip_de(html, "SC") =~ "accent-orange"
      refute chip_de(html, "SC") =~ "accent-green"
    end

    test "marking from the sheet flips the chip color right away", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.student), ~p"/study")

      render_click(lv, "open_step_sheet", %{"code" => "SC"})
      html = render_click(lv, "toggle_step_learned", %{"code" => "SC"})

      assert chip_de(html, "SC") =~ "accent-green"
    end
  end

  describe "on the workshop page" do
    test "steps of the class change color too", ctx do
      owner = insert(:user)
      workshop = insert(:workshop, organizer: owner)
      {:ok, _} = Workshops.enroll(workshop, ctx.student)
      {:ok, _} = Workshops.add_step(workshop, owner, ctx.known_step.id)
      {:ok, _} = Workshops.add_step(workshop, owner, ctx.unknown_step.id)

      {:ok, _lv, html} =
        live(log_in_user(build_conn(), ctx.student), ~p"/workshops/#{workshop.slug}")

      assert chip_de(html, "IV") =~ "accent-green"
      assert chip_de(html, "SC") =~ "accent-orange"
    end
  end

  describe "the sheet is the chip opened" do
    test "opening a known step brings a green sheet", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.student), ~p"/study")

      html = render_click(lv, "open_step_sheet", %{"code" => "IV"})

      assert html =~ "Você já sabe este passo"
      assert sheet(html) =~ "accent-green"
    end

    test "opening a new step brings an amber sheet", ctx do
      {:ok, lv, _} = live(log_in_user(build_conn(), ctx.student), ~p"/study")

      html = render_click(lv, "open_step_sheet", %{"code" => "SC"})

      assert html =~ "Já sei este passo"
      assert sheet(html) =~ "accent-orange"
    end
  end

  defp chip_de(html, code) do
    case :binary.match(html, ">#{code}</code>") do
      {inicio, _} -> binary_part(html, max(inicio - 400, 0), min(400, inicio))
      :nomatch -> flunk("não achei o chip de #{code}")
    end
  end

  defp sheet(html) do
    case Regex.run(~r/id="step-sheet".{0,3000}/s, html) do
      [trecho] -> trecho
      nil -> flunk("folha não está aberta")
    end
  end
end
