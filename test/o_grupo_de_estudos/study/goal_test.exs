defmodule OGrupoDeEstudos.Study.GoalTest do
  use ExUnit.Case, async: true

  alias OGrupoDeEstudos.Study.Goal

  describe "changeset/2 owner XOR" do
    test "valid with only owner_user_id, which is a personal goal" do
      cs = Goal.changeset(%Goal{}, %{body: "Treinar BF", owner_user_id: Ecto.UUID.generate()})
      assert cs.valid?
    end

    test "valid with only teacher_student_link_id, which is a shared goal" do
      cs =
        Goal.changeset(%Goal{}, %{
          body: "Treinar BF",
          teacher_student_link_id: Ecto.UUID.generate()
        })

      assert cs.valid?
    end

    test "invalid with no owner at all" do
      cs = Goal.changeset(%Goal{}, %{body: "Treinar BF"})
      refute cs.valid?
    end

    test "invalid with both owners" do
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
