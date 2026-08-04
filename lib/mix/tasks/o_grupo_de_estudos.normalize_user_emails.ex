defmodule Mix.Tasks.OGrupoDeEstudos.NormalizeUserEmails do
  @moduledoc """
  Backfills stored user emails to their lowercase, trimmed form.

  Emails whose lowercase form already belongs to another user are left
  untouched and listed for manual review.

  ## Usage

      mix o_grupo_de_estudos.normalize_user_emails
  """

  use Mix.Task

  alias OGrupoDeEstudos.Accounts

  @shortdoc "Backfills stored user emails to lowercase"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    {normalized, conflicts} = Accounts.normalize_all_emails()

    Mix.shell().info("Emails normalized: #{normalized}")
    Enum.each(conflicts, &Mix.shell().error("Conflict, needs manual review: #{&1}"))
  end
end
