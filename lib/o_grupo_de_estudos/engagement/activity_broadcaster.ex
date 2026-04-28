defmodule OGrupoDeEstudos.Engagement.ActivityBroadcaster do
  @moduledoc """
  Broadcasts user actions to followers' activity feeds in real-time.

  When a user performs an action (like, follow, create sequence, etc.),
  this module broadcasts to each follower's personal PubSub channel.
  The follower's LiveView picks it up and shows an ephemeral toast.

  ## Disabling

  If toasts feel like spam or cause performance issues:
  1. Remove `broadcast_activity/3` calls from Engagement context
  2. Remove the `handle_info(:activity_toast, ...)` from ActivityToastHandlers
  3. Remove `<.activity_toast>` from templates
  The module itself has no side effects when unused.

  ## Performance

  Each broadcast fans out to N followers. For users with many followers,
  this could be expensive. Current mitigation: cap at 50 followers per
  broadcast. Future: consider async via Oban if needed.
  """

  alias OGrupoDeEstudos.Engagement

  @max_fan_out 50

  @doc """
  Broadcasts an activity to all followers of the actor.

  ## Parameters
  - `actor` — the user who performed the action (%User{})
  - `action` — atom describing the action (:liked_step, :followed_user, :created_sequence)
  - `metadata` — map with additional context (step name, target username, etc.)
  """
  def broadcast_activity(actor, action, metadata \\ %{}) do
    follower_ids =
      Engagement.following_ids_reverse(actor.id)
      |> Enum.take(@max_fan_out)

    message = %{
      actor_username: actor.username,
      actor_name: actor.name,
      action: action,
      metadata: metadata,
      timestamp: System.system_time(:second)
    }

    for follower_id <- follower_ids do
      Phoenix.PubSub.broadcast(
        OGrupoDeEstudos.PubSub,
        "activity:#{follower_id}",
        {:activity_toast, message}
      )
    end

    :ok
  end
end
