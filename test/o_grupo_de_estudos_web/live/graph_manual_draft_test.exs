defmodule OGrupoDeEstudosWeb.GraphManualDraftTest do
  @moduledoc """
  Leaving the editor by the URL has to leave the editing behind with it.

  `?mode=manual` is the link that opens the manual builder to make a new
  sequence. It cleared a key called `editing_sequence_id`, which no other line
  in the app writes or reads: the real key is `seq_editing_id`. So whoever was
  editing a sequence and then followed that link kept editing it without being
  told, and saving overwrote the sequence they had opened instead of creating
  the new one.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.Sequences

  setup do
    author = insert(:user)
    section = insert(:section)
    first = insert(:step, section: section, code: "BF", name: "Base frontal")
    second = insert(:step, section: section, code: "IV", name: "Inversão")

    {:ok, saved} =
      Sequences.create_manual_sequence(author.id, %{
        "name" => "Aquecimento de sábado",
        "step_codes" => [first.code, second.code]
      })

    %{author: author, saved: saved, first: first, second: second}
  end

  test "the builder opened fresh from the URL saves a new sequence", ctx do
    {:ok, lv, _html} = live(log_in_user(ctx.conn, ctx.author), ~p"/graph/visual")

    render_click(lv, "edit_saved_sequence", %{"id" => ctx.saved.id})

    # A pessoa desiste da edição e usa o link que abre o construtor em branco.
    # Patch, não remontagem: é o que o link faz, e é o que mantém o estado.
    render_patch(lv, ~p"/graph/visual?mode=manual")

    render_click(lv, "add_manual_step", %{"code" => ctx.first.code, "name" => ctx.first.name})

    render_submit(lv, "save_manual_sequence", %{"name" => "Sequência nova", "description" => ""})

    minhas = Sequences.list_user_sequences(ctx.author.id)

    assert length(minhas) == 2, "salvar no construtor em branco tem que criar, não sobrescrever"
    assert Enum.any?(minhas, &(&1.name == "Sequência nova"))

    assert Enum.any?(minhas, &(&1.name == "Aquecimento de sábado")),
           "a sequência que estava aberta para edição não pode ser sobrescrita"
  end

  test "the key the builder clears is the one the app actually reads", _ctx do
    fonte = File.read!("lib/o_grupo_de_estudos_web/live/graph_visual_live.ex")

    refute fonte =~ "editing_sequence_id",
           "só existe seq_editing_id; a variante longa não é lida por nenhum template nem handler"
  end
end
