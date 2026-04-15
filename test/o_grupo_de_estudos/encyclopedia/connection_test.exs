defmodule OGrupoDeEstudos.Encyclopedia.ConnectionTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Encyclopedia.Connection

  describe "changeset/2" do
    test "accepts optional label and description" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")

      changeset =
        Connection.changeset(%Connection{}, %{
          source_step_id: source.id,
          target_step_id: target.id,
          label: "Trava Armada",
          description: "Ambos jogam centro de massa para direita gerando elástico."
        })

      assert changeset.valid?
      assert changeset.changes.label == "Trava Armada"

      assert changeset.changes.description ==
               "Ambos jogam centro de massa para direita gerando elástico."
    end

    test "valid without label and description" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")

      changeset =
        Connection.changeset(%Connection{}, %{
          source_step_id: source.id,
          target_step_id: target.id
        })

      assert changeset.valid?
    end
  end
end
