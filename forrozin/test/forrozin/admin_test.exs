defmodule Forrozin.AdminTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Admin

  # ---------------------------------------------------------------------------
  # create_connection/1
  # ---------------------------------------------------------------------------

  describe "create_connection/1" do
    test "creates valid connection between two steps" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")

      assert {:ok, connection} =
               Admin.create_connection(%{
                 source_step_id: source.id,
                 target_step_id: target.id,
                 
               })

      assert connection.source_step_id == source.id
      assert connection.target_step_id == target.id
    end

    test "returns error when source step does not exist" do
      target = insert(:step, code: "SC")
      nonexistent_id = Ecto.UUID.generate()

      assert {:error, changeset} =
               Admin.create_connection(%{
                 source_step_id: nonexistent_id,
                 target_step_id: target.id,
                 
               })

      assert changeset.errors[:source_step_id] != nil
    end

    test "returns constraint error for duplicate connection" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")
      insert(:connection, source_step: source, target_step: target)

      assert {:error, changeset} =
               Admin.create_connection(%{
                 source_step_id: source.id,
                 target_step_id: target.id,
                 
               })

      assert changeset.errors[:source_step_id] != nil or
               changeset.errors[:target_step_id] != nil
    end

    test "creates connection with optional label and description" do
      source = insert(:step, code: "ARM-D")
      target = insert(:step, code: "TR-ARM")

      assert {:ok, connection} =
               Admin.create_connection(%{
                 source_step_id: source.id,
                 target_step_id: target.id,
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
    test "updates label of an existing connection" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")
      connection = insert(:connection, source_step: source, target_step: target)

      assert {:ok, updated} = Admin.update_connection(connection.id, %{label: "Trava Armada"})
      assert updated.label == "Trava Armada"
    end

    test "updates description of an existing connection" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")
      connection = insert(:connection, source_step: source, target_step: target)

      assert {:ok, updated} =
               Admin.update_connection(connection.id, %{description: "Nova descrição."})

      assert updated.description == "Nova descrição."
    end

    test "returns error for nonexistent ID" do
      assert {:error, :not_found} = Admin.update_connection(Ecto.UUID.generate(), %{label: "X"})
    end
  end

  # ---------------------------------------------------------------------------
  # delete_connection/1
  # ---------------------------------------------------------------------------

  describe "delete_connection/1" do
    test "removes an existing connection" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")
      connection = insert(:connection, source_step: source, target_step: target)

      assert {:ok, deleted} = Admin.delete_connection(connection.id)
      assert deleted.id == connection.id
      assert Forrozin.Repo.get(Forrozin.Encyclopedia.Connection, connection.id) == nil
    end

    test "returns error for nonexistent ID" do
      assert {:error, :not_found} = Admin.delete_connection(Ecto.UUID.generate())
    end
  end
end
