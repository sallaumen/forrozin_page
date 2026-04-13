defmodule Forrozin.Enciclopedia.SubsecaoTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Enciclopedia.Subsecao

  describe "changeset/2" do
    test "válido com campos obrigatórios" do
      secao = insert(:secao)
      attrs = %{titulo: "Entradas no GP", posicao: 0, secao_id: secao.id}
      assert %{valid?: true} = Subsecao.changeset(%Subsecao{}, attrs)
    end

    test "inválido sem título" do
      secao = insert(:secao)
      attrs = %{posicao: 0, secao_id: secao.id}
      changeset = Subsecao.changeset(%Subsecao{}, attrs)
      assert "can't be blank" in errors_on(changeset).titulo
    end

    test "inválido sem secao_id" do
      attrs = %{titulo: "Entradas no GP", posicao: 0}
      changeset = Subsecao.changeset(%Subsecao{}, attrs)
      assert "can't be blank" in errors_on(changeset).secao_id
    end
  end
end
