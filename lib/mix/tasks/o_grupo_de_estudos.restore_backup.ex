defmodule Mix.Tasks.OGrupoDeEstudos.RestoreBackup do
  @moduledoc """
  Restores the database from a JSON backup file.

  ## Usage

      # List available backups
      mix o_grupo_de_estudos.restore_backup

      # Restore (on_conflict: :nothing — does not overwrite existing data)
      mix o_grupo_de_estudos.restore_backup priv/backups/backup_20260411_130000.json

      # Restore from scratch (clears existing data before restoring)
      mix o_grupo_de_estudos.restore_backup priv/backups/backup_20260411_130000.json --clear
  """

  use Mix.Task

  @shortdoc "Restores the database from a JSON backup"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    alias OGrupoDeEstudos.Admin.Backup

    case args do
      [] ->
        list_backups(Backup)

      [path | flags] ->
        clear = "--clear" in flags

        if clear do
          Mix.shell().info("⚠️  Clearing existing data before restoring...")
          clear_tables!()
        end

        Mix.shell().info("Restoring from #{path}...")
        Backup.restore_backup!(path)
        Mix.shell().info("✓ Restore complete.")
    end
  end

  defp list_backups(backup_mod) do
    backups = backup_mod.list_backups()

    if backups == [] do
      Mix.shell().info("No backups found.")
    else
      Mix.shell().info("Available backups (most recent first):\n")
      Enum.each(backups, fn path -> Mix.shell().info("  #{path}") end)
      Mix.shell().info("\nUsage: mix o_grupo_de_estudos.restore_backup PATH")
    end
  end

  defp clear_tables! do
    repo = OGrupoDeEstudos.Repo

    # Reverse order of FK constraints
    repo.query!("DELETE FROM concept_steps")
    repo.query!("DELETE FROM step_connections")
    repo.delete_all(OGrupoDeEstudos.Encyclopedia.Step)
    repo.delete_all(OGrupoDeEstudos.Encyclopedia.TechnicalConcept)
    repo.delete_all(OGrupoDeEstudos.Encyclopedia.Subsection)
    repo.delete_all(OGrupoDeEstudos.Encyclopedia.Section)
    repo.delete_all(OGrupoDeEstudos.Encyclopedia.Category)
  end
end
