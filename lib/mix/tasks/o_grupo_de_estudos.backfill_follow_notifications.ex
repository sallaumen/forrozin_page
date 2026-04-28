defmodule Mix.Tasks.OGrupoDeEstudos.BackfillFollowNotifications do
  @moduledoc """
  Creates missing notifications for existing follow relationships.

  ## Usage

      mix o_grupo_de_estudos.backfill_follow_notifications --dry-run
      mix o_grupo_de_estudos.backfill_follow_notifications
      mix o_grupo_de_estudos.backfill_follow_notifications --limit 100
  """

  use Mix.Task

  import Ecto.Query

  alias OGrupoDeEstudos.Engagement.Follow
  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias OGrupoDeEstudos.Repo

  @shortdoc "Backfills follow notifications for existing follows"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _argv, _invalid} =
      OptionParser.parse(args, strict: [dry_run: :boolean, limit: :integer])

    dry_run? = Keyword.get(opts, :dry_run, false)
    limit = Keyword.get(opts, :limit)

    follows = list_follows(limit)

    {created, skipped} =
      Enum.reduce(follows, {0, 0}, fn follow, acc ->
        process_follow(follow, dry_run?, acc)
      end)

    verb = if dry_run?, do: "would create", else: "created"
    Mix.shell().info("Follow notifications #{verb}: #{created}")
    Mix.shell().info("Already present: #{skipped}")
  end

  defp process_follow(follow, dry_run?, {created, skipped}) do
    if notification_exists?(follow) do
      {created, skipped + 1}
    else
      unless dry_run?, do: create_notification!(follow)
      {created + 1, skipped}
    end
  end

  defp list_follows(nil) do
    from(f in Follow, order_by: [asc: f.inserted_at])
    |> Repo.all()
  end

  defp list_follows(limit) do
    from(f in Follow, order_by: [asc: f.inserted_at], limit: ^limit)
    |> Repo.all()
  end

  defp notification_exists?(%Follow{} = follow) do
    Repo.exists?(
      from(n in Notification,
        where:
          n.user_id == ^follow.followed_id and
            n.actor_id == ^follow.follower_id and
            n.action == "followed_user"
      )
    )
  end

  defp create_notification!(%Follow{} = follow) do
    %Notification{}
    |> Notification.changeset(%{
      user_id: follow.followed_id,
      actor_id: follow.follower_id,
      action: "followed_user",
      group_key: "follow:#{follow.followed_id}",
      target_type: "profile",
      target_id: follow.follower_id,
      parent_type: "profile",
      parent_id: follow.follower_id,
      inserted_at: follow.inserted_at
    })
    |> Repo.insert!()

    Phoenix.PubSub.broadcast(
      OGrupoDeEstudos.PubSub,
      "notifications:#{follow.followed_id}",
      {:new_notification, 1}
    )
  end
end
