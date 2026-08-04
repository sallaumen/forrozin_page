defmodule OGrupoDeEstudos.StepsSeenInClassTest do
  @moduledoc """
  Quais passos esta pessoa já viu numa aula.

  É histórico, não decisão: "aprendido" a pessoa marca quando quer, "visto em
  aula" é o que aconteceu com ela. Cada contexto responde pelas próprias
  tabelas — o acervo junta as duas respostas.

  A regra é a mesma em toda fonte: só conta aula de que a pessoa participou.
  Dizer "você viu" sobre uma aula alheia seria mentira.
  """

  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.{Study, Workshops}

  setup do
    %{
      passo: insert(:step, code: "IV", name: "Inversão base"),
      outro: insert(:step, code: "SCSP", name: "Sacada com sacada de perna")
    }
  end

  describe "passos vistos em workshop" do
    setup ctx do
      dono = insert(:user)
      workshop = insert(:workshop, organizer: dono)
      {:ok, _} = Workshops.add_step(workshop, dono, ctx.passo.id)

      ctx |> Map.put(:dono, dono) |> Map.put(:workshop, workshop)
    end

    test "quem se inscreveu viu", ctx do
      aluna = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.workshop, aluna)

      assert MapSet.member?(Workshops.step_ids_seen_by(aluna.id), ctx.passo.id)
    end

    test "quem organizou também viu", ctx do
      assert MapSet.member?(Workshops.step_ids_seen_by(ctx.dono.id), ctx.passo.id)
    end

    test "quem não esteve na aula não viu", _ctx do
      assert Workshops.step_ids_seen_by(insert(:user).id) == MapSet.new()
    end

    test "passo que o workshop não deu não entra", ctx do
      aluna = insert(:user)
      {:ok, _} = Workshops.enroll(ctx.workshop, aluna)

      refute MapSet.member?(Workshops.step_ids_seen_by(aluna.id), ctx.outro.id)
    end

    test "visitante sem conta não tem histórico" do
      assert Workshops.step_ids_seen_by(nil) == MapSet.new()
    end
  end

  describe "passos vistos em nota de estudo" do
    test "o passo que a pessoa anotou no próprio diário", ctx do
      aluna = insert(:user)

      {:ok, _} =
        Study.upsert_personal_note(aluna, Date.utc_today(), %{
          content: "Treinei inversão.",
          step_ids: [ctx.passo.id]
        })

      assert MapSet.member?(Study.step_ids_seen_by(aluna.id), ctx.passo.id)
    end

    test "o passo que o professor marcou na nota compartilhada vale para os dois", ctx do
      link = insert(:teacher_student_link, active: true)

      {:ok, _} =
        Study.upsert_shared_note(link, Date.utc_today(), %{
          content: "Aula de hoje.",
          step_ids: [ctx.passo.id]
        })

      assert MapSet.member?(Study.step_ids_seen_by(link.student_id), ctx.passo.id)
      assert MapSet.member?(Study.step_ids_seen_by(link.teacher_id), ctx.passo.id)
    end

    test "a nota de outra pessoa não conta", ctx do
      outra = insert(:user)

      {:ok, _} =
        Study.upsert_personal_note(outra, Date.utc_today(), %{
          content: "Treinei.",
          step_ids: [ctx.passo.id]
        })

      assert Study.step_ids_seen_by(insert(:user).id) == MapSet.new()
    end
  end

  describe "passos vistos em lição do professor" do
    setup ctx do
      teacher = insert(:user, is_teacher: true)
      link = insert(:teacher_student_link, teacher: teacher, active: true)

      {:ok, _lesson, _} =
        Study.broadcast_lesson(
          teacher,
          %{title: "Aula", content: "Texto", step_ids: [ctx.passo.id]},
          [link.id]
        )

      ctx |> Map.put(:teacher, teacher) |> Map.put(:link, link)
    end

    test "o aluno que recebeu a lição viu o passo", ctx do
      assert MapSet.member?(Study.step_ids_seen_by(ctx.link.student_id), ctx.passo.id)
    end

    test "quem deu a aula também viu", ctx do
      assert MapSet.member?(Study.step_ids_seen_by(ctx.teacher.id), ctx.passo.id)
    end

    test "quem não recebeu a lição não viu", _ctx do
      assert Study.step_ids_seen_by(insert(:user).id) == MapSet.new()
    end
  end

  test "visitante sem conta não tem histórico de estudo" do
    assert Study.step_ids_seen_by(nil) == MapSet.new()
  end
end
