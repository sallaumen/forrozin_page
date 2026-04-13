defmodule Forrozin.Enciclopedia.CategoriaTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Enciclopedia.Categoria

  describe "changeset/2" do
    test "válido com todos os campos obrigatórios" do
      attrs = %{nome: "sacadas", rotulo: "Sacadas", cor: "#c0392b"}
      assert %{valid?: true} = Categoria.changeset(%Categoria{}, attrs)
    end

    test "inválido sem nome" do
      changeset = Categoria.changeset(%Categoria{}, %{rotulo: "Sacadas", cor: "#c0392b"})
      assert "can't be blank" in errors_on(changeset).nome
    end

    test "inválido sem rótulo" do
      changeset = Categoria.changeset(%Categoria{}, %{nome: "sacadas", cor: "#c0392b"})
      assert "can't be blank" in errors_on(changeset).rotulo
    end

    test "inválido sem cor" do
      changeset = Categoria.changeset(%Categoria{}, %{nome: "sacadas", rotulo: "Sacadas"})
      assert "can't be blank" in errors_on(changeset).cor
    end

    test "nome deve ser único no banco" do
      insert(:categoria, nome: "sacadas")

      {:error, changeset} =
        %Categoria{}
        |> Categoria.changeset(%{nome: "sacadas", rotulo: "Sacadas Duplicadas", cor: "#ff0000"})
        |> Forrozin.Repo.insert()

      assert "has already been taken" in errors_on(changeset).nome
    end
  end
end
