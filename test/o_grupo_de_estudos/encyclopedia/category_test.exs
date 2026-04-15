defmodule OGrupoDeEstudos.Encyclopedia.CategoryTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Encyclopedia.Category

  describe "changeset/2" do
    test "valid with all required fields" do
      attrs = %{name: "sacadas", label: "Sacadas", color: "#c0392b"}
      assert %{valid?: true} = Category.changeset(%Category{}, attrs)
    end

    test "invalid without name" do
      changeset = Category.changeset(%Category{}, %{label: "Sacadas", color: "#c0392b"})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "invalid without label" do
      changeset = Category.changeset(%Category{}, %{name: "sacadas", color: "#c0392b"})
      assert "can't be blank" in errors_on(changeset).label
    end

    test "invalid without color" do
      changeset = Category.changeset(%Category{}, %{name: "sacadas", label: "Sacadas"})
      assert "can't be blank" in errors_on(changeset).color
    end

    test "name must be unique in the database" do
      insert(:category, name: "sacadas")

      {:error, changeset} =
        %Category{}
        |> Category.changeset(%{name: "sacadas", label: "Sacadas Duplicadas", color: "#ff0000"})
        |> OGrupoDeEstudos.Repo.insert()

      assert "has already been taken" in errors_on(changeset).name
    end
  end
end
