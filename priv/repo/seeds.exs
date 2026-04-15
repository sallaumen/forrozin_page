# Seed the database from the latest backup.
#
#     mix run priv/repo/seeds.exs
#
# This restores all data (steps, connections, users, sequences, etc.)
# from the most recent backup file. Idempotent — safe to run multiple times.

alias OGrupoDeEstudos.Admin.Backup

backups = Backup.list_backups()

case backups do
  [latest | _] ->
    IO.puts("Restoring from: #{Path.basename(latest)}")
    Backup.restore_backup!(latest)
    IO.puts("Seed complete — all data restored from backup.")

  [] ->
    IO.puts("No backup files found in #{inspect(Backup.list_backups())}")
    IO.puts("Run the seeder instead:")
    IO.puts("  OGrupoDeEstudos.Encyclopedia.Seeder.seed!()")
    IO.puts("Then create a backup for future seeds.")
end
