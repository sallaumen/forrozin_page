defmodule OGrupoDeEstudosWeb.CollectionSeenIconTest do
  @moduledoc """
  Collection cards show a "seen in class" icon, separate from the "learned"
  icon: learned is the user's own decision, seen in class is history. A step
  can be one without the other, and both can coexist on the same card.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Engagement, Workshops}

  @seen_title "Você viu este passo em aula"
  @learned_title "Você já sabe este passo"

  setup %{conn: conn} do
    section = insert(:section, code: "TEST", title: "Bases")
    step = insert(:step, section: section, code: "IV", name: "Inversão base")
    student = insert(:user)

    %{conn: log_in_user(conn, student), student: student, section: section, step: step}
  end

  defp open_section(ctx) do
    {:ok, lv, _html} = live(ctx.conn, ~p"/collection")
    render_patch(lv, "/collection?section=#{ctx.section.id}")
  end

  defp attend_workshop_teaching(student, step) do
    owner = insert(:user)
    workshop = insert(:workshop, organizer: owner)
    {:ok, _} = Workshops.enroll(workshop, student)
    {:ok, _} = Workshops.add_step(workshop, owner, step.id)
  end

  describe "seen-in-class icon" do
    test "absent on a step the user never saw", ctx do
      refute open_section(ctx) =~ @seen_title
    end

    test "present after a workshop the user attended", ctx do
      attend_workshop_teaching(ctx.student, ctx.step)

      assert open_section(ctx) =~ @seen_title
    end

    test "present for a step noted in the diary", ctx do
      {:ok, _} =
        OGrupoDeEstudos.Study.upsert_personal_note(ctx.student, Date.utc_today(), %{
          content: "Treinei inversão.",
          step_ids: [ctx.step.id]
        })

      assert open_section(ctx) =~ @seen_title
    end

    test "someone else's workshop does not light the icon", ctx do
      owner = insert(:user)
      workshop = insert(:workshop, organizer: owner)
      {:ok, _} = Workshops.add_step(workshop, owner, ctx.step.id)

      refute open_section(ctx) =~ @seen_title
    end
  end

  describe "seen and learned are different things" do
    test "seen in class does not mark as learned", ctx do
      attend_workshop_teaching(ctx.student, ctx.step)
      html = open_section(ctx)

      assert html =~ @seen_title
      refute html =~ @learned_title
      refute Engagement.learned?(ctx.student.id, ctx.step.id)
    end

    test "learned without any class shows only the learned icon", ctx do
      Engagement.toggle_learned(ctx.student.id, ctx.step.id)
      html = open_section(ctx)

      assert html =~ @learned_title
      refute html =~ @seen_title
    end

    test "both icons coexist on the same card", ctx do
      attend_workshop_teaching(ctx.student, ctx.step)
      Engagement.toggle_learned(ctx.student.id, ctx.step.id)
      html = open_section(ctx)

      assert html =~ @seen_title
      assert html =~ @learned_title
    end
  end

  describe "in the collection search" do
    test "search results also show the history", ctx do
      attend_workshop_teaching(ctx.student, ctx.step)

      {:ok, lv, _} = live(ctx.conn, ~p"/collection")
      html = render_change(lv, "search", %{"term" => "Inversão"})

      assert html =~ @seen_title
    end
  end
end
