defmodule OGrupoDeEstudos.DataMigrations.SendConfirmationToExistingUsers do
  @moduledoc """
  One-time script: generates confirmation tokens and sends confirmation
  emails to all existing users who don't have confirmed_at set.

  Users who already have confirmed_at are skipped.
  """

  @behaviour OGrupoDeEstudos.DataMigrations.DataMigrationScript

  import Ecto.Query

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Repo

  require Logger

  @impl true
  def name, do: "2026-04-29-send-confirmation-to-existing-users"

  @impl true
  def run_once?, do: true

  @impl true
  def run do
    users =
      from(u in User, where: is_nil(u.confirmed_at))
      |> Repo.all()

    count =
      Enum.reduce(users, 0, fn user, acc ->
        token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

        user
        |> Ecto.Changeset.change(%{confirmation_token: token})
        |> Repo.update!()

        %{user_id: user.id}
        |> OGrupoDeEstudos.Workers.SendConfirmationEmail.new()
        |> Oban.insert!()

        Logger.info("[SendConfirmation] Enqueued for #{user.email}")
        acc + 1
      end)

    "#{count} emails enqueued"
  end
end
