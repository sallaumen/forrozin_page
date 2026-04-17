# scripts/cleanup_fake_users.exs
#
# Removes all fake users and their associated data.
# Fake users are identified by username starting with "fake_user_".
#
# Usage:
#   mix run scripts/cleanup_fake_users.exs
#   mix run scripts/cleanup_fake_users.exs --dry-run
#
# NEVER run in production.

Code.require_file("scripts/script_helper.exs")

alias OGrupoDeEstudos.{Accounts.User, Repo}
import Ecto.Query

ScriptHelper.guard_not_production!()

dry_run = ScriptHelper.dry_run?()

IO.puts("\n\e[1m=== CLEANUP FAKE USERS ===\e[0m\n")

fake_users = Repo.all(
  from u in User,
    where: like(u.username, "fake_user_%"),
    select: %{id: u.id, username: u.username}
)

if fake_users == [] do
  ScriptHelper.log(:info, "No fake users found. Nothing to clean.")
else
  ScriptHelper.log(:info, "Found #{length(fake_users)} fake user(s):")

  Enum.each(fake_users, fn u ->
    ScriptHelper.log(:info, "  @#{u.username} (#{u.id})")
  end)

  if dry_run do
    ScriptHelper.log(:warn, "DRY RUN: no data deleted")
  else
    ScriptHelper.log(:step, "Deleting fake users (cascades to likes, comments, follows, etc.)")

    ids = Enum.map(fake_users, & &1.id)
    {count, _} = Repo.delete_all(from u in User, where: u.id in ^ids)

    ScriptHelper.log(:ok, "Deleted #{count} user(s) and all associated data")
  end
end

IO.puts("")
