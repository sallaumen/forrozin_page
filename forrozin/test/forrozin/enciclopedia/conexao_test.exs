defmodule Forrozin.Enciclopedia.ConexaoTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Enciclopedia.Conexao

  describe "changeset/2" do
    test "aceita rotulo e descricao opcionais" do
      origem = insert(:passo, codigo: "BF")
      destino = insert(:passo, codigo: "SC")

      changeset =
        Conexao.changeset(%Conexao{}, %{
          passo_origem_id: origem.id,
          passo_destino_id: destino.id,
          tipo: "saida",
          rotulo: "Trava Armada",
          descricao: "Ambos jogam CDM para direita gerando elástico."
        })

      assert changeset.valid?
      assert changeset.changes.rotulo == "Trava Armada"
      assert changeset.changes.descricao == "Ambos jogam CDM para direita gerando elástico."
    end

    test "é válido sem rotulo e descricao" do
      origem = insert(:passo, codigo: "BF")
      destino = insert(:passo, codigo: "SC")

      changeset =
        Conexao.changeset(%Conexao{}, %{
          passo_origem_id: origem.id,
          passo_destino_id: destino.id,
          tipo: "saida"
        })

      assert changeset.valid?
    end
  end
end
