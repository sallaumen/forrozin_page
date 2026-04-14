defmodule Forrozin.AdminTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Admin

  # ---------------------------------------------------------------------------
  # create_connection/1
  # ---------------------------------------------------------------------------

  describe "create_connection/1" do
    test "cria conexão válida entre dois passos" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")

      assert {:ok, connection} =
               Admin.create_connection(%{
                 source_step_id: source.id,
                 target_step_id: target.id,
                 type: "exit"
               })

      assert connection.source_step_id == source.id
      assert connection.target_step_id == target.id
      assert connection.type == "exit"
    end

    test "retorna erro para tipo inválido" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")

      assert {:error, changeset} =
               Admin.create_connection(%{
                 source_step_id: source.id,
                 target_step_id: target.id,
                 type: "invalido"
               })

      assert "is invalid" in errors_on(changeset).type
    end

    test "retorna erro quando passo de origem não existe" do
      target = insert(:step, code: "SC")
      nonexistent_id = Ecto.UUID.generate()

      assert {:error, changeset} =
               Admin.create_connection(%{
                 source_step_id: nonexistent_id,
                 target_step_id: target.id,
                 type: "exit"
               })

      assert changeset.errors[:source_step_id] != nil
    end

    test "retorna erro de constraint para conexão duplicada" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")
      insert(:connection, source_step: source, target_step: target, type: "exit")

      assert {:error, changeset} =
               Admin.create_connection(%{
                 source_step_id: source.id,
                 target_step_id: target.id,
                 type: "exit"
               })

      assert changeset.errors[:source_step_id] != nil or
               changeset.errors[:target_step_id] != nil
    end

    test "cria conexão com label e description opcionais" do
      source = insert(:step, code: "ARM-D")
      target = insert(:step, code: "TR-ARM")

      assert {:ok, connection} =
               Admin.create_connection(%{
                 source_step_id: source.id,
                 target_step_id: target.id,
                 type: "exit",
                 label: "Trava Armada",
                 description: "Ambos jogam centro de massa para direita gerando elástico."
               })

      assert connection.label == "Trava Armada"
      assert connection.description == "Ambos jogam centro de massa para direita gerando elástico."
    end
  end

  # ---------------------------------------------------------------------------
  # update_connection/2
  # ---------------------------------------------------------------------------

  describe "update_connection/2" do
    test "atualiza label de uma conexão existente" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")
      connection = insert(:connection, source_step: source, target_step: target, type: "exit")

      assert {:ok, updated} = Admin.update_connection(connection.id, %{label: "Trava Armada"})
      assert updated.label == "Trava Armada"
    end

    test "atualiza description de uma conexão existente" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")
      connection = insert(:connection, source_step: source, target_step: target, type: "exit")

      assert {:ok, updated} =
               Admin.update_connection(connection.id, %{description: "Nova descrição."})

      assert updated.description == "Nova descrição."
    end

    test "retorna erro para ID inexistente" do
      assert {:error, :not_found} = Admin.update_connection(Ecto.UUID.generate(), %{label: "X"})
    end
  end

  # ---------------------------------------------------------------------------
  # delete_connection/1
  # ---------------------------------------------------------------------------

  describe "delete_connection/1" do
    test "remove uma conexão existente" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")
      connection = insert(:connection, source_step: source, target_step: target, type: "exit")

      assert {:ok, deleted} = Admin.delete_connection(connection.id)
      assert deleted.id == connection.id
      assert Forrozin.Repo.get(Forrozin.Encyclopedia.Connection, connection.id) == nil
    end

    test "retorna erro para ID inexistente" do
      assert {:error, :not_found} = Admin.delete_connection(Ecto.UUID.generate())
    end
  end
end
