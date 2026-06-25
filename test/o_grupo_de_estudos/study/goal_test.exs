defmodule OGrupoDeEstudos.Study.GoalTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudos.Study.Goal

  describe "changeset/2 — XOR de dono" do
    test "válida com apenas owner_user_id (meta pessoal)" do
      cs = Goal.changeset(%Goal{}, %{body: "Treinar BF", owner_user_id: Ecto.UUID.generate()})
      assert cs.valid?
    end

    test "válida com apenas teacher_student_link_id (meta compartilhada)" do
      cs =
        Goal.changeset(%Goal{}, %{
          body: "Treinar BF",
          teacher_student_link_id: Ecto.UUID.generate()
        })

      assert cs.valid?
    end

    test "inválida sem nenhum dono" do
      cs = Goal.changeset(%Goal{}, %{body: "Treinar BF"})
      refute cs.valid?
    end

    test "inválida com ambos os donos" do
      cs =
        Goal.changeset(%Goal{}, %{
          body: "Treinar BF",
          owner_user_id: Ecto.UUID.generate(),
          teacher_student_link_id: Ecto.UUID.generate()
        })

      refute cs.valid?
    end
  end
end
