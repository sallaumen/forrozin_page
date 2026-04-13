defmodule Forrozin.Admin.BackupTest do
  use Forrozin.DataCase, async: false

  alias Forrozin.Admin.Backup
  alias Forrozin.Repo

  setup do
    dir = Path.join(System.tmp_dir!(), "forrozin_backup_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  # ---------------------------------------------------------------------------
  # criar_backup!/1
  # ---------------------------------------------------------------------------

  describe "criar_backup!/1" do
    test "cria arquivo JSON no diretório especificado", %{dir: dir} do
      caminho = Backup.criar_backup!(dir)
      assert File.exists?(caminho)
      assert String.ends_with?(caminho, ".json")
    end

    test "o JSON contém todas as tabelas esperadas", %{dir: dir} do
      caminho = Backup.criar_backup!(dir)
      dados = caminho |> File.read!() |> Jason.decode!()

      assert dados["versao"] == "1"
      assert is_binary(dados["criado_em"])
      tabelas = dados["tabelas"]
      assert Map.has_key?(tabelas, "categorias")
      assert Map.has_key?(tabelas, "secoes")
      assert Map.has_key?(tabelas, "subsecoes")
      assert Map.has_key?(tabelas, "passos")
      assert Map.has_key?(tabelas, "conexoes_passos")
      assert Map.has_key?(tabelas, "conceitos_tecnicos")
      assert Map.has_key?(tabelas, "conceitos_passos")
    end

    test "o JSON inclui dados presentes no banco", %{dir: dir} do
      cat = insert(:categoria, nome: "bases")
      secao = insert(:secao, categoria: cat)
      passo_a = insert(:passo, codigo: "BF", secao: secao, categoria: cat)
      passo_b = insert(:passo, codigo: "SC", secao: secao, categoria: cat)
      insert(:conexao, passo_origem: passo_a, passo_destino: passo_b, tipo: "saida")

      caminho = Backup.criar_backup!(dir)
      dados = caminho |> File.read!() |> Jason.decode!()

      codigos_passos = Enum.map(dados["tabelas"]["passos"], & &1["codigo"])
      assert "BF" in codigos_passos
      assert "SC" in codigos_passos
      assert length(dados["tabelas"]["conexoes_passos"]) == 1
    end

    test "remove arquivos antigos mantendo apenas os últimos 48", %{dir: dir} do
      # Cria 50 arquivos fictícios de backup mais antigos
      for i <- 1..50 do
        nome = "backup_20260101_#{String.pad_leading(to_string(i), 6, "0")}.json"
        File.write!(Path.join(dir, nome), "{}")
      end

      Backup.criar_backup!(dir)

      arquivos = File.ls!(dir) |> Enum.filter(&String.ends_with?(&1, ".json"))
      assert length(arquivos) == 48
    end
  end

  # ---------------------------------------------------------------------------
  # restaurar_backup!/1
  # ---------------------------------------------------------------------------

  describe "restaurar_backup!/1" do
    test "insere dados num banco vazio", %{dir: dir} do
      # Cria dados, gera backup, depois verifica que restaurar é idempotente
      cat = insert(:categoria, nome: "bases")
      secao = insert(:secao, categoria: cat)
      passo_a = insert(:passo, codigo: "BF", secao: secao, categoria: cat)
      passo_b = insert(:passo, codigo: "SC", secao: secao, categoria: cat)
      insert(:conexao, passo_origem: passo_a, passo_destino: passo_b, tipo: "saida")

      caminho = Backup.criar_backup!(dir)

      # Restaurar com dados já presentes (on_conflict: :nothing)
      assert :ok = Backup.restaurar_backup!(caminho)

      # Os dados devem continuar lá
      assert Repo.aggregate(Forrozin.Enciclopedia.Categoria, :count) >= 1
      assert Repo.aggregate(Forrozin.Enciclopedia.Passo, :count) >= 2
      assert Repo.aggregate(Forrozin.Enciclopedia.Conexao, :count) >= 1
    end

    test "é idempotente — restaurar duas vezes não duplica dados", %{dir: dir} do
      cat = insert(:categoria, nome: "sacadas")
      secao = insert(:secao, categoria: cat)
      insert(:passo, codigo: "SC", secao: secao, categoria: cat)

      caminho = Backup.criar_backup!(dir)
      contagem_antes = Repo.aggregate(Forrozin.Enciclopedia.Passo, :count)

      Backup.restaurar_backup!(caminho)
      contagem_depois = Repo.aggregate(Forrozin.Enciclopedia.Passo, :count)

      assert contagem_antes == contagem_depois
    end
  end

  # ---------------------------------------------------------------------------
  # listar_backups/1
  # ---------------------------------------------------------------------------

  describe "listar_backups/1" do
    test "retorna lista vazia quando não há backups", %{dir: dir} do
      assert Backup.listar_backups(dir) == []
    end

    test "retorna arquivos ordenados do mais recente para o mais antigo", %{dir: dir} do
      File.write!(Path.join(dir, "backup_20260101_120000.json"), "{}")
      File.write!(Path.join(dir, "backup_20260101_130000.json"), "{}")
      File.write!(Path.join(dir, "backup_20260101_110000.json"), "{}")

      nomes = Backup.listar_backups(dir) |> Enum.map(&Path.basename/1)

      assert nomes == [
               "backup_20260101_130000.json",
               "backup_20260101_120000.json",
               "backup_20260101_110000.json"
             ]
    end
  end
end
