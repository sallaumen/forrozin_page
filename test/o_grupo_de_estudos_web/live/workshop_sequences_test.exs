defmodule OGrupoDeEstudosWeb.WorkshopSequencesTest do
  @moduledoc """
  The sequence of a class, on the page of that class.

  A workshop lists the steps it taught, but a step list is not a sequence: the
  class covers one or two names and the combination is a separate thing. Whoever
  teaches cites the refined sequence here, and whoever attends takes it home by
  favoriting.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Brazil, Engagement, Workshops}

  defp at_day(days) do
    Brazil.today()
    |> Date.add(days)
    |> DateTime.new!(Time.new!(14, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  defp published(organizer) do
    {:ok, workshop} =
      Workshops.create_workshop(organizer, %{
        title: "Workshop de pisada",
        description: "Conteúdo.",
        location: "Curitiba",
        starts_at: at_day(7)
      })

    {:ok, workshop} = Workshops.publish_workshop(organizer, workshop)
    workshop
  end

  setup do
    teacher = insert(:user)
    student = insert(:user)
    workshop = published(teacher)

    step_1 = insert(:step, code: "BF", name: "Base frontal")
    step_2 = insert(:step, code: "SC", name: "Sacada")

    sequence = insert(:sequence, user: teacher, name: "Entrada de sacada")
    insert(:sequence_step, sequence: sequence, step: step_1, position: 1)
    insert(:sequence_step, sequence: sequence, step: step_2, position: 2)

    %{
      teacher: teacher,
      student: student,
      workshop: workshop,
      sequence: sequence,
      step_1: step_1,
      step_2: step_2
    }
  end

  defp open(conn, ctx, user),
    do: live(log_in_user(conn, user), ~p"/workshops/#{ctx.workshop.slug}")

  describe "who may cite" do
    test "the teacher gets both ways in", %{conn: conn} = ctx do
      {:ok, _lv, html} = open(conn, ctx, ctx.teacher)

      assert html =~ "montar sequência"
      assert html =~ "citar uma minha"
    end

    test "a student gets neither", %{conn: conn} = ctx do
      {:ok, _lv, html} = open(conn, ctx, ctx.student)

      refute html =~ "montar sequência"
      refute html =~ "citar uma minha"
    end

    test "a student sending the event anyway cites nothing", %{conn: conn} = ctx do
      {:ok, lv, _} = open(conn, ctx, ctx.student)

      render_click(lv, "cite_sequence", %{"id" => ctx.sequence.id})

      assert Workshops.list_sequences(ctx.workshop.id) == []
    end
  end

  describe "citing one that already exists" do
    test "the sheet lists what the teacher saved", %{conn: conn} = ctx do
      {:ok, lv, _} = open(conn, ctx, ctx.teacher)

      html = render_click(lv, "open_sequence_sheet", %{"tab" => "mine"})

      assert html =~ "Entrada de sacada"
    end

    test "citing puts it on the class page with its step count", %{conn: conn} = ctx do
      {:ok, lv, _} = open(conn, ctx, ctx.teacher)

      html = render_click(lv, "cite_sequence", %{"id" => ctx.sequence.id})

      assert [cited] = Workshops.list_sequences(ctx.workshop.id)
      assert cited.name == "Entrada de sacada"
      assert cited.step_count == 2
      assert html =~ "Entrada de sacada"
    end

    test "the citation can be taken back, and the sequence survives", %{conn: conn} = ctx do
      {:ok, lv, _} = open(conn, ctx, ctx.teacher)
      render_click(lv, "cite_sequence", %{"id" => ctx.sequence.id})

      render_click(lv, "uncite_sequence", %{"id" => ctx.sequence.id})

      assert Workshops.list_sequences(ctx.workshop.id) == []
      assert OGrupoDeEstudos.Sequences.get_sequence(ctx.sequence.id)
    end
  end

  describe "building one on the spot" do
    test "saving creates it for the teacher and cites it here", %{conn: conn} = ctx do
      {:ok, lv, _} = open(conn, ctx, ctx.teacher)
      render_click(lv, "open_sequence_sheet", %{"tab" => "new"})
      render_click(lv, "sequence_draft_add", %{"code" => "BF"})
      render_click(lv, "sequence_draft_add", %{"code" => "SC"})
      render_keyup(lv, "sequence_draft_name", %{"value" => "Saída pela sacada"})

      html = render_click(lv, "save_sequence", %{})

      assert Enum.any?(
               Workshops.list_sequences(ctx.workshop.id),
               &(&1.name == "Saída pela sacada" and &1.user_id == ctx.teacher.id)
             )

      assert html =~ "Saída pela sacada"
    end

    test "a draft with a single step is refused", %{conn: conn} = ctx do
      {:ok, lv, _} = open(conn, ctx, ctx.teacher)
      render_click(lv, "open_sequence_sheet", %{"tab" => "new"})
      render_click(lv, "sequence_draft_add", %{"code" => "BF"})
      render_keyup(lv, "sequence_draft_name", %{"value" => "Curta demais"})

      html = render_click(lv, "save_sequence", %{})

      assert html =~ "pelo menos dois passos"
      assert Workshops.list_sequences(ctx.workshop.id) == []
    end
  end

  describe "what whoever attends does with it" do
    setup ctx do
      {:ok, _} = Workshops.add_sequence(ctx.workshop, ctx.teacher, ctx.sequence.id)
      ctx
    end

    test "the student sees the cited sequence", %{conn: conn} = ctx do
      {:ok, _lv, html} = open(conn, ctx, ctx.student)

      assert html =~ "Entrada de sacada"
      assert html =~ "Sequências desta aula"
    end

    test "opening it shows the steps in order, without leaving the page", %{conn: conn} = ctx do
      {:ok, lv, _} = open(conn, ctx, ctx.student)

      html = render_click(lv, "toggle_sequence_steps", %{"id" => ctx.sequence.id})

      assert html =~ "Base frontal"
      assert html =~ "Sacada"
      assert [_, _] = Regex.scan(~r/data-sequence-step=/, html)
    end

    test "clicking it again closes it", %{conn: conn} = ctx do
      {:ok, lv, _} = open(conn, ctx, ctx.student)
      render_click(lv, "toggle_sequence_steps", %{"id" => ctx.sequence.id})

      html = render_click(lv, "toggle_sequence_steps", %{"id" => ctx.sequence.id})

      refute html =~ "data-sequence-step="
    end

    test "favoriting takes it home, and the heart fills in", %{conn: conn} = ctx do
      {:ok, lv, _} = open(conn, ctx, ctx.student)

      html = render_click(lv, "toggle_sequence_favorite", %{"id" => ctx.sequence.id})

      assert Engagement.favorited?(ctx.student.id, "sequence", ctx.sequence.id)
      assert html =~ "hero-heart-solid"
    end

    test "a sequence nobody favorited shows the empty heart", %{conn: conn} = ctx do
      {:ok, _lv, html} = open(conn, ctx, ctx.student)

      refute html =~ "hero-heart-solid"
    end

    test "favoriting again gives it back", %{conn: conn} = ctx do
      {:ok, lv, _} = open(conn, ctx, ctx.student)
      render_click(lv, "toggle_sequence_favorite", %{"id" => ctx.sequence.id})

      render_click(lv, "toggle_sequence_favorite", %{"id" => ctx.sequence.id})

      refute Engagement.favorited?(ctx.student.id, "sequence", ctx.sequence.id)
    end

    test "a visitor with no account is sent to sign up instead", %{conn: conn} = ctx do
      {:ok, lv, _} = live(conn, ~p"/workshops/#{ctx.workshop.slug}")

      assert {:error, {:redirect, %{to: "/signup"}}} =
               render_click(lv, "toggle_sequence_favorite", %{"id" => ctx.sequence.id})
    end
  end

  describe "when there is nothing to show" do
    test "the section stays out of the way for whoever attends", %{conn: conn} = ctx do
      {:ok, _lv, html} = open(conn, ctx, ctx.student)

      refute html =~ "Sequências desta aula"
    end

    test "the teacher still sees the invitation to build one", %{conn: conn} = ctx do
      {:ok, _lv, html} = open(conn, ctx, ctx.teacher)

      assert html =~ "Sequências desta aula"
      assert html =~ "montar sequência"
    end
  end
end
