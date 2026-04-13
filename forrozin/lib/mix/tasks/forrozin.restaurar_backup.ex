defmodule Mix.Tasks.Forrozin.RestaurarBackup do
  @moduledoc """
  Restaura o banco de dados a partir de um arquivo de backup JSON.

  ## Uso

      # Listar backups disponíveis
      mix forrozin.restaurar_backup

      # Restaurar (on_conflict: :nothing — não sobrescreve dados existentes)
      mix forrozin.restaurar_backup priv/backups/backup_20260411_130000.json

      # Restaurar do zero (apaga dados existentes antes de restaurar)
      mix forrozin.restaurar_backup priv/backups/backup_20260411_130000.json --limpar
  """

  use Mix.Task

  @shortdoc "Restaura o banco a partir de um backup JSON"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    alias Forrozin.Admin.Backup

    case args do
      [] ->
        listar_backups(Backup)

      [caminho | flags] ->
        limpar = "--limpar" in flags

        if limpar do
          Mix.shell().info("⚠️  Limpando dados existentes antes de restaurar...")
          limpar_tabelas!()
        end

        Mix.shell().info("Restaurando a partir de #{caminho}...")
        Backup.restaurar_backup!(caminho)
        Mix.shell().info("✓ Restauração concluída.")
    end
  end

  defp listar_backups(backup_mod) do
    backups = backup_mod.listar_backups()

    if backups == [] do
      Mix.shell().info("Nenhum backup encontrado.")
    else
      Mix.shell().info("Backups disponíveis (do mais recente):\n")
      Enum.each(backups, fn caminho -> Mix.shell().info("  #{caminho}") end)
      Mix.shell().info("\nUso: mix forrozin.restaurar_backup CAMINHO")
    end
  end

  defp limpar_tabelas! do
    repo = Forrozin.Repo

    # Ordem reversa de FK constraints
    repo.query!("DELETE FROM conceitos_passos")
    repo.query!("DELETE FROM conexoes_passos")
    repo.delete_all(Forrozin.Enciclopedia.Passo)
    repo.delete_all(Forrozin.Enciclopedia.ConceitoTecnico)
    repo.delete_all(Forrozin.Enciclopedia.Subsecao)
    repo.delete_all(Forrozin.Enciclopedia.Secao)
    repo.delete_all(Forrozin.Enciclopedia.Categoria)
  end
end
