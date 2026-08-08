defmodule Mix.Tasks.OGrupoDeEstudos.BackfillGoogleWelcomeEmails do
  @moduledoc """
  Sends the welcome email to google-born accounts that predate it.

  `--before` marks when the welcome email for Google sign-ins shipped, so
  accounts that already got it at registration stay out. `--dry-run` only
  lists who would receive it.

  ## Usage

      mix o_grupo_de_estudos.backfill_google_welcome_emails --before 2026-08-08T18:00:00Z --dry-run
      mix o_grupo_de_estudos.backfill_google_welcome_emails --before 2026-08-08T18:00:00Z
  """

  use Mix.Task

  alias OGrupoDeEstudos.Accounts

  @shortdoc "Sends the welcome email to google-born accounts that predate it"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _argv, _invalid} =
      OptionParser.parse(args, strict: [before: :string, dry_run: :boolean])

    cutoff = parse_cutoff(opts[:before])

    if Keyword.get(opts, :dry_run, false) do
      emails = cutoff |> Accounts.list_google_registered_before() |> Enum.map(& &1.email)
      Mix.shell().info("Would send to #{length(emails)}: #{Enum.join(emails, ", ")}")
    else
      {count, emails} = Accounts.backfill_welcome_emails(cutoff)
      Mix.shell().info("Welcome emails enqueued: #{count} (#{Enum.join(emails, ", ")})")
    end
  end

  defp parse_cutoff(nil),
    do: Mix.raise("--before is required (ISO 8601, e.g. 2026-08-08T18:00:00Z)")

  defp parse_cutoff(iso) do
    case DateTime.from_iso8601(iso) do
      {:ok, cutoff, _offset} -> cutoff
      {:error, _reason} -> Mix.raise("--before must be ISO 8601, e.g. 2026-08-08T18:00:00Z")
    end
  end
end
