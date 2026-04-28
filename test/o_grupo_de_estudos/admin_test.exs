defmodule OGrupoDeEstudos.AdminTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Admin
  alias OGrupoDeEstudos.Encyclopedia.{ConnectionQuery, Step, StepQuery}
  alias OGrupoDeEstudos.Repo

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
                 target_step_id: target.id
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
                 target_step_id: target.id
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
                 target_step_id: target.id
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

      assert connection.description ==
               "Ambos jogam centro de massa para direita gerando elástico."
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
    test "soft-deletes an existing connection by setting deleted_at" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")
      connection = insert(:connection, source_step: source, target_step: target)

      assert {:ok, deleted} = Admin.delete_connection(connection.id)
      assert deleted.id == connection.id
      assert deleted.deleted_at != nil

      # Row still exists in the database
      row = OGrupoDeEstudos.Repo.get(OGrupoDeEstudos.Encyclopedia.Connection, connection.id)
      assert row != nil
      assert row.deleted_at != nil
    end

    test "excluded from default queries after soft delete" do
      source = insert(:step, code: "BF")
      target = insert(:step, code: "SC")
      connection = insert(:connection, source_step: source, target_step: target)

      {:ok, _} = Admin.delete_connection(connection.id)

      assert is_nil(
               ConnectionQuery.get_by(
                 source_step_id: source.id,
                 target_step_id: target.id
               )
             )
    end

    test "returns error for nonexistent ID" do
      assert {:error, :not_found} = Admin.delete_connection(Ecto.UUID.generate())
    end
  end

  describe "update_step/2" do
    test "updates step name" do
      step = insert(:step, code: "BF", name: "Base frontal")
      assert {:ok, updated} = Admin.update_step(step, %{name: "Base frontal v2"})
      assert updated.name == "Base frontal v2"
    end
  end

  describe "delete_step/1" do
    test "soft-deletes a step by setting deleted_at" do
      step = insert(:step, code: "BF")

      assert {:ok, deleted} = Admin.delete_step(step)
      assert deleted.deleted_at != nil

      # Row still exists in the database
      row = Repo.get(Step, step.id)
      assert row != nil
      assert row.deleted_at != nil
    end

    test "excluded from default StepQuery after soft delete" do
      step = insert(:step, code: "BF")

      {:ok, _} = Admin.delete_step(step)

      assert is_nil(StepQuery.get_by(code: "BF"))
    end

    test "visible with include_deleted: true after soft delete" do
      step = insert(:step, code: "BF")

      {:ok, _} = Admin.delete_step(step)

      assert StepQuery.get_by(code: "BF", include_deleted: true) !=
               nil
    end
  end

  describe "create_step/1" do
    test "creates step with valid data" do
      cat = insert(:category)
      section = insert(:section, category: cat)

      assert {:ok, step} =
               Admin.create_step(%{
                 code: "NEW",
                 name: "Novo",
                 section_id: section.id,
                 category_id: cat.id
               })

      assert step.code == "NEW"
    end
  end

  describe "update_section/2" do
    test "updates section title" do
      section = insert(:section, title: "Bases")
      assert {:ok, updated} = Admin.update_section(section, %{title: "Bases v2"})
      assert updated.title == "Bases v2"
    end
  end

  describe "create_section/1" do
    test "creates section with valid data" do
      assert {:ok, section} = Admin.create_section(%{title: "Nova", position: 99})
      assert section.title == "Nova"
    end
  end

  describe "create_category/1" do
    test "creates category with valid data" do
      assert {:ok, cat} = Admin.create_category(%{name: "nova", label: "Nova", color: "#ff0000"})
      assert cat.name == "nova"
    end
  end

  describe "update_category/2" do
    test "updates category label" do
      cat = insert(:category, name: "bases", label: "Bases")
      assert {:ok, updated} = Admin.update_category(cat, %{label: "Bases v2"})
      assert updated.label == "Bases v2"
    end
  end
end
