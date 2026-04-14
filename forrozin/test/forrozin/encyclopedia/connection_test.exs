defmodule Forrozin.Encyclopedia.ConnectionTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Encyclopedia.Connection

  describe "changeset/2" do
    test "aceita label e description opcionais" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")

      changeset =
        Connection.changeset(%Connection{}, %{
          source_step_id: source.id,
          target_step_id: target.id,
          type: "exit",
          label: "Trava Armada",
          description: "Ambos jogam centro de massa para direita gerando elástico."
        })

      assert changeset.valid?
      assert changeset.changes.label == "Trava Armada"
      assert changeset.changes.description == "Ambos jogam centro de massa para direita gerando elástico."
    end

    test "é válido sem label e description" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")

      changeset =
        Connection.changeset(%Connection{}, %{
          source_step_id: source.id,
          target_step_id: target.id,
          type: "exit"
        })

      assert changeset.valid?
    end
  end
end
