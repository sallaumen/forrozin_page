defmodule Forrozin.Encyclopedia.CategoryTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Encyclopedia.Category

  describe "changeset/2" do
    test "válido com todos os campos obrigatórios" do
      attrs = %{name: "sacadas", label: "Sacadas", color: "#c0392b"}
      assert %{valid?: true} = Category.changeset(%Category{}, attrs)
    end

    test "inválido sem nome" do
      changeset = Category.changeset(%Category{}, %{label: "Sacadas", color: "#c0392b"})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "inválido sem rótulo" do
      changeset = Category.changeset(%Category{}, %{name: "sacadas", color: "#c0392b"})
      assert "can't be blank" in errors_on(changeset).label
    end

    test "inválido sem cor" do
      changeset = Category.changeset(%Category{}, %{name: "sacadas", label: "Sacadas"})
      assert "can't be blank" in errors_on(changeset).color
    end

    test "nome deve ser único no banco" do
      insert(:category, name: "sacadas")

      {:error, changeset} =
        %Category{}
        |> Category.changeset(%{name: "sacadas", label: "Sacadas Duplicadas", color: "#ff0000"})
        |> Forrozin.Repo.insert()

      assert "has already been taken" in errors_on(changeset).name
    end
  end
end
