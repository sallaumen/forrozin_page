defmodule OGrupoDeEstudos.Encyclopedia.StepTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Encyclopedia.Step

  describe "changeset/2" do
    test "valid with all required fields" do
      section = insert(:section)
      attrs = %{code: "BF", name: "Base frontal", position: 0, section_id: section.id}
      assert %{valid?: true} = Step.changeset(%Step{}, attrs)
    end

    test "default status is published" do
      section = insert(:section)
      attrs = %{code: "BF", name: "Base frontal", position: 0, section_id: section.id}
      changeset = Step.changeset(%Step{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :status) == "published"
    end

    test "default wip is false" do
      section = insert(:section)
      attrs = %{code: "BF", name: "Base frontal", position: 0, section_id: section.id}
      changeset = Step.changeset(%Step{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :wip) == false
    end

    test "invalid without code" do
      section = insert(:section)
      attrs = %{name: "Base frontal", position: 0, section_id: section.id}
      changeset = Step.changeset(%Step{}, attrs)
      assert "can't be blank" in errors_on(changeset).code
    end

    test "invalid without name" do
      section = insert(:section)
      attrs = %{code: "BF", position: 0, section_id: section.id}
      changeset = Step.changeset(%Step{}, attrs)
      assert "can't be blank" in errors_on(changeset).name
    end

    test "status must be published or draft" do
      section = insert(:section)

      attrs = %{
        code: "BF",
        name: "Base frontal",
        position: 0,
        section_id: section.id,
        status: "invalido"
      }

      changeset = Step.changeset(%Step{}, attrs)
      assert "is invalid" in errors_on(changeset).status
    end

    test "code must be unique in the database" do
      insert(:step, code: "BF")
      section = insert(:section)

      {:error, changeset} =
        %Step{}
        |> Step.changeset(%{code: "BF", name: "Outro", position: 1, section_id: section.id})
        |> OGrupoDeEstudos.Repo.insert()

      assert "has already been taken" in errors_on(changeset).code
    end
  end
end
