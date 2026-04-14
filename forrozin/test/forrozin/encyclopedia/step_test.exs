defmodule Forrozin.Encyclopedia.StepTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Encyclopedia.Step

  describe "changeset/2" do
    test "válido com todos os campos obrigatórios" do
      section = insert(:section)
      attrs = %{code: "BF", name: "Base frontal", position: 0, section_id: section.id}
      assert %{valid?: true} = Step.changeset(%Step{}, attrs)
    end

    test "status padrão é published" do
      section = insert(:section)
      attrs = %{code: "BF", name: "Base frontal", position: 0, section_id: section.id}
      changeset = Step.changeset(%Step{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :status) == "published"
    end

    test "wip padrão é false" do
      section = insert(:section)
      attrs = %{code: "BF", name: "Base frontal", position: 0, section_id: section.id}
      changeset = Step.changeset(%Step{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :wip) == false
    end

    test "inválido sem código" do
      section = insert(:section)
      attrs = %{name: "Base frontal", position: 0, section_id: section.id}
      changeset = Step.changeset(%Step{}, attrs)
      assert "can't be blank" in errors_on(changeset).code
    end

    test "inválido sem nome" do
      section = insert(:section)
      attrs = %{code: "BF", position: 0, section_id: section.id}
      changeset = Step.changeset(%Step{}, attrs)
      assert "can't be blank" in errors_on(changeset).name
    end

    test "status deve ser published ou draft" do
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

    test "código deve ser único no banco" do
      insert(:step, code: "BF")
      section = insert(:section)

      {:error, changeset} =
        %Step{}
        |> Step.changeset(%{code: "BF", name: "Outro", position: 1, section_id: section.id})
        |> Forrozin.Repo.insert()

      assert "has already been taken" in errors_on(changeset).code
    end
  end
end
