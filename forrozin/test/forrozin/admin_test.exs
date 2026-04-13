defmodule Forrozin.AdminTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Admin

  # ---------------------------------------------------------------------------
  # criar_conexao/1
  # ---------------------------------------------------------------------------

  describe "criar_conexao/1" do
    test "cria conexão válida entre dois passos" do
      origem = insert(:passo, codigo: "BF")
      destino = insert(:passo, codigo: "SC")

      assert {:ok, conexao} =
               Admin.criar_conexao(%{
                 passo_origem_id: origem.id,
                 passo_destino_id: destino.id,
                 tipo: "saida"
               })

      assert conexao.passo_origem_id == origem.id
      assert conexao.passo_destino_id == destino.id
      assert conexao.tipo == "saida"
    end

    test "retorna erro para tipo inválido" do
      origem = insert(:passo, codigo: "BF")
      destino = insert(:passo, codigo: "SC")

      assert {:error, changeset} =
               Admin.criar_conexao(%{
                 passo_origem_id: origem.id,
                 passo_destino_id: destino.id,
                 tipo: "invalido"
               })

      assert "is invalid" in errors_on(changeset).tipo
    end

    test "retorna erro quando passo de origem não existe" do
      destino = insert(:passo, codigo: "SC")
      id_inexistente = Ecto.UUID.generate()

      assert {:error, changeset} =
               Admin.criar_conexao(%{
                 passo_origem_id: id_inexistente,
                 passo_destino_id: destino.id,
                 tipo: "saida"
               })

      assert changeset.errors[:passo_origem_id] != nil
    end

    test "retorna erro de constraint para conexão duplicada" do
      origem = insert(:passo, codigo: "BF")
      destino = insert(:passo, codigo: "SC")
      insert(:conexao, passo_origem: origem, passo_destino: destino, tipo: "saida")

      assert {:error, changeset} =
               Admin.criar_conexao(%{
                 passo_origem_id: origem.id,
                 passo_destino_id: destino.id,
                 tipo: "saida"
               })

      assert changeset.errors[:passo_origem_id] != nil or
               changeset.errors[:passo_destino_id] != nil
    end

    test "cria conexão com rótulo e descrição opcionais" do
      origem = insert(:passo, codigo: "ARM-D")
      destino = insert(:passo, codigo: "TR-ARM")

      assert {:ok, conexao} =
               Admin.criar_conexao(%{
                 passo_origem_id: origem.id,
                 passo_destino_id: destino.id,
                 tipo: "saida",
                 rotulo: "Trava Armada",
                 descricao: "Ambos jogam CDM para direita gerando elástico."
               })

      assert conexao.rotulo == "Trava Armada"
      assert conexao.descricao == "Ambos jogam CDM para direita gerando elástico."
    end
  end

  # ---------------------------------------------------------------------------
  # editar_conexao/2
  # ---------------------------------------------------------------------------

  describe "editar_conexao/2" do
    test "atualiza rotulo de uma conexão existente" do
      origem = insert(:passo, codigo: "BF")
      destino = insert(:passo, codigo: "SC")
      conexao = insert(:conexao, passo_origem: origem, passo_destino: destino, tipo: "saida")

      assert {:ok, atualizada} = Admin.editar_conexao(conexao.id, %{rotulo: "Trava Armada"})
      assert atualizada.rotulo == "Trava Armada"
    end

    test "atualiza descricao de uma conexão existente" do
      origem = insert(:passo, codigo: "BF")
      destino = insert(:passo, codigo: "SC")
      conexao = insert(:conexao, passo_origem: origem, passo_destino: destino, tipo: "saida")

      assert {:ok, atualizada} =
               Admin.editar_conexao(conexao.id, %{descricao: "Nova descrição."})

      assert atualizada.descricao == "Nova descrição."
    end

    test "retorna erro para ID inexistente" do
      assert {:error, :nao_encontrado} = Admin.editar_conexao(Ecto.UUID.generate(), %{rotulo: "X"})
    end
  end

  # ---------------------------------------------------------------------------
  # remover_conexao/1
  # ---------------------------------------------------------------------------

  describe "remover_conexao/1" do
    test "remove uma conexão existente" do
      origem = insert(:passo, codigo: "BF")
      destino = insert(:passo, codigo: "SC")
      conexao = insert(:conexao, passo_origem: origem, passo_destino: destino, tipo: "saida")

      assert {:ok, removida} = Admin.remover_conexao(conexao.id)
      assert removida.id == conexao.id
      assert Forrozin.Repo.get(Forrozin.Enciclopedia.Conexao, conexao.id) == nil
    end

    test "retorna erro para ID inexistente" do
      assert {:error, :nao_encontrado} = Admin.remover_conexao(Ecto.UUID.generate())
    end
  end
end
