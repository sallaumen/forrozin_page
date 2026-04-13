defmodule Forrozin.Enciclopedia.SecaoTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Enciclopedia.Secao

  describe "changeset/2" do
    test "válido com campos obrigatórios" do
      categoria = insert(:categoria)
      attrs = %{titulo: "Bases", posicao: 1, categoria_id: categoria.id}
      assert %{valid?: true} = Secao.changeset(%Secao{}, attrs)
    end

    test "válido sem num e sem codigo (seções de convenções e conceitos)" do
      categoria = insert(:categoria)
      attrs = %{titulo: "Convenções", posicao: 0, categoria_id: categoria.id}
      assert %{valid?: true} = Secao.changeset(%Secao{}, attrs)
    end

    test "inválido sem título" do
      categoria = insert(:categoria)
      attrs = %{posicao: 1, categoria_id: categoria.id}
      changeset = Secao.changeset(%Secao{}, attrs)
      assert "can't be blank" in errors_on(changeset).titulo
    end

    test "inválido sem posição" do
      categoria = insert(:categoria)
      attrs = %{titulo: "Bases", categoria_id: categoria.id}
      changeset = Secao.changeset(%Secao{}, attrs)
      assert "can't be blank" in errors_on(changeset).posicao
    end
  end
end
