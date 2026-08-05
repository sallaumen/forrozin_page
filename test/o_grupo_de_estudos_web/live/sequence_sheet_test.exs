defmodule OGrupoDeEstudosWeb.SequenceSheetTest do
  @moduledoc """
  Building or citing a sequence from inside the diary, without leaving the note.

  Until now a sequence was reachable only through the manual builder on the map, so
  the combination that worked in class was written as prose and lost its shape.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Sequences, Study}

  setup do
    student = insert(:user)

    %{
      student: student,
      step_1: insert(:step, code: "BF", name: "Base frontal"),
      step_2: insert(:step, code: "SC", name: "Sacada"),
      conn: log_in_user(build_conn(), student)
    }
  end

  defp open_study(ctx), do: live(ctx.conn, ~p"/study")

  describe "the shortcut in the diary" do
    test "the note offers building a sequence", ctx do
      {:ok, _lv, html} = open_study(ctx)

      assert html =~ "montar sequência"
    end

    test "opening the sheet shows the empty track", ctx do
      {:ok, lv, _} = open_study(ctx)

      html = render_click(lv, "open_sequence_sheet", %{"tab" => "new"})

      assert html =~ "A sequência"
      assert html =~ "Nenhum passo ainda"
    end

    test "the sheet closes", ctx do
      {:ok, lv, _} = open_study(ctx)

      render_click(lv, "open_sequence_sheet", %{"tab" => "new"})
      html = render_click(lv, "close_sequence_sheet", %{})

      refute html =~ "Nenhum passo ainda"
    end
  end

  describe "the draft survives the sheet" do
    test "switching tabs keeps the steps already picked", ctx do
      {:ok, lv, _} = open_study(ctx)
      render_click(lv, "open_sequence_sheet", %{"tab" => "new"})
      render_click(lv, "sequence_draft_add", %{"code" => "BF"})

      render_click(lv, "sequence_sheet_tab", %{"tab" => "mine"})
      html = render_click(lv, "sequence_sheet_tab", %{"tab" => "new"})

      assert html =~ "Base frontal"
    end

    test "reopening after closing starts clean", ctx do
      {:ok, lv, _} = open_study(ctx)
      render_click(lv, "open_sequence_sheet", %{"tab" => "new"})
      render_click(lv, "sequence_draft_add", %{"code" => "BF"})
      render_click(lv, "close_sequence_sheet", %{})

      html = render_click(lv, "open_sequence_sheet", %{"tab" => "new"})

      assert html =~ "Nenhum passo ainda"
    end

    test "picking a step clears the search box for the next one", ctx do
      {:ok, lv, _} = open_study(ctx)
      render_click(lv, "open_sequence_sheet", %{"tab" => "new"})
      render_keyup(lv, "sequence_search_step", %{"value" => "Base"})

      html = render_click(lv, "sequence_draft_add", %{"code" => "BF"})

      assert html =~ ~s(name="step_search" value="")
    end
  end

  describe "building one" do
    test "searching offers steps, and picking puts them on the track", ctx do
      {:ok, lv, _} = open_study(ctx)
      render_click(lv, "open_sequence_sheet", %{"tab" => "new"})

      html = render_keyup(lv, "sequence_search_step", %{"value" => "Base"})
      assert html =~ "Base frontal"

      html = render_click(lv, "sequence_draft_add", %{"code" => "BF"})
      assert html =~ "BF"
    end

    test "saving needs a name and at least two steps", ctx do
      {:ok, lv, _} = open_study(ctx)
      render_click(lv, "open_sequence_sheet", %{"tab" => "new"})
      render_click(lv, "sequence_draft_add", %{"code" => "BF"})
      render_keyup(lv, "sequence_draft_name", %{"value" => "Só um passo"})

      html = render_click(lv, "save_sequence", %{})

      assert html =~ "pelo menos dois passos"
      assert Sequences.list_user_sequences(ctx.student.id) == []
    end

    test "a nameless draft is refused", ctx do
      {:ok, lv, _} = open_study(ctx)
      render_click(lv, "open_sequence_sheet", %{"tab" => "new"})
      render_click(lv, "sequence_draft_add", %{"code" => "BF"})
      render_click(lv, "sequence_draft_add", %{"code" => "SC"})

      html = render_click(lv, "save_sequence", %{})

      assert html =~ "Dê um nome"
    end

    test "saving creates the sequence for the person and cites it on the note", ctx do
      {:ok, lv, _} = open_study(ctx)
      render_click(lv, "open_sequence_sheet", %{"tab" => "new"})
      render_click(lv, "sequence_draft_add", %{"code" => "BF"})
      render_click(lv, "sequence_draft_add", %{"code" => "SC"})
      render_keyup(lv, "sequence_draft_name", %{"value" => "Entrada de sacada"})

      html = render_click(lv, "save_sequence", %{})

      assert [sequence] = Sequences.list_user_sequences(ctx.student.id)
      assert sequence.name == "Entrada de sacada"
      assert sequence.user_id == ctx.student.id
      assert html =~ "Entrada de sacada"
    end

    test "the order the drag pushed is the order that gets saved", ctx do
      {:ok, lv, _} = open_study(ctx)
      render_click(lv, "open_sequence_sheet", %{"tab" => "new"})
      render_click(lv, "sequence_draft_add", %{"code" => "BF"})
      render_click(lv, "sequence_draft_add", %{"code" => "SC"})

      render_hook(lv, "sequence_draft_reorder", %{"order" => ["1", "0"]})
      render_keyup(lv, "sequence_draft_name", %{"value" => "Invertida"})
      render_click(lv, "save_sequence", %{})

      assert [sequence] = Sequences.list_user_sequences(ctx.student.id)
      assert ["SC", "BF"] = Enum.map(sequence.sequence_steps, & &1.step.code)
    end

    test "an order that does not cover every position is ignored", ctx do
      {:ok, lv, _} = open_study(ctx)
      render_click(lv, "open_sequence_sheet", %{"tab" => "new"})
      render_click(lv, "sequence_draft_add", %{"code" => "BF"})
      render_click(lv, "sequence_draft_add", %{"code" => "SC"})

      render_hook(lv, "sequence_draft_reorder", %{"order" => ["1"]})
      render_keyup(lv, "sequence_draft_name", %{"value" => "Intacta"})
      render_click(lv, "save_sequence", %{})

      assert [sequence] = Sequences.list_user_sequences(ctx.student.id)
      assert ["BF", "SC"] = Enum.map(sequence.sequence_steps, & &1.step.code)
    end

    test "a step can be dropped from the track", ctx do
      {:ok, lv, _} = open_study(ctx)
      render_click(lv, "open_sequence_sheet", %{"tab" => "new"})
      render_click(lv, "sequence_draft_add", %{"code" => "BF"})
      render_click(lv, "sequence_draft_add", %{"code" => "SC"})

      html = render_click(lv, "sequence_draft_remove", %{"index" => "0"})

      refute html =~ "Base frontal"
      assert html =~ "Sacada"
    end
  end

  describe "citing one that already exists" do
    setup ctx do
      sequence = insert(:sequence, user: ctx.student, name: "Aquecimento de pisada")
      insert(:sequence_step, sequence: sequence, step: ctx.step_1)
      Map.put(ctx, :sequence, sequence)
    end

    test "the tab lists what the person already saved", ctx do
      {:ok, lv, _} = open_study(ctx)

      html = render_click(lv, "open_sequence_sheet", %{"tab" => "mine"})

      assert html =~ "Aquecimento de pisada"
    end

    test "citing puts it on the note without creating a second sequence", ctx do
      {:ok, lv, _} = open_study(ctx)
      render_click(lv, "open_sequence_sheet", %{"tab" => "mine"})

      html = render_click(lv, "cite_sequence", %{"id" => ctx.sequence.id})

      assert html =~ "Aquecimento de pisada"
      assert length(Sequences.list_user_sequences(ctx.student.id)) == 1
    end

    test "citing survives a reload, because it lives on the note", ctx do
      {:ok, lv, _} = open_study(ctx)
      render_click(lv, "cite_sequence", %{"id" => ctx.sequence.id})

      {:ok, _lv, html} = open_study(ctx)

      assert html =~ "Aquecimento de pisada"
    end

    test "the citation can be taken back", ctx do
      {:ok, lv, _} = open_study(ctx)
      render_click(lv, "cite_sequence", %{"id" => ctx.sequence.id})

      html = render_click(lv, "uncite_sequence", %{"id" => ctx.sequence.id})

      refute html =~ "Aquecimento de pisada"
    end

    test "citing does not lose what was already typed in the note", ctx do
      {:ok, lv, _} = open_study(ctx)

      render_submit(lv, "save_personal_note", %{
        "personal_note" => %{"content" => "Aula boa hoje."}
      })

      render_click(lv, "cite_sequence", %{"id" => ctx.sequence.id})

      # Brazil.today() and not Date.utc_today(): the page writes the note on the
      # local date, and after 21h in Curitiba the UTC day is already tomorrow.
      note = Study.get_personal_note(ctx.student.id, OGrupoDeEstudos.Brazil.today())
      assert note.content == "Aula boa hoje."
    end
  end
end
