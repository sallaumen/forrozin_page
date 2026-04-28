defmodule OGrupoDeEstudos.Engagement.Notifications.Grouper do
  @moduledoc """
  Transforms raw notifications into display-ready maps.
  Each notification is individual (no grouping).
  """

  def group(notifications) do
    notifications
    |> Enum.map(fn notif ->
      %{
        id: notif.id,
        action: notif.action,
        actors: [notif.actor_id],
        actors_data: [notif.actor],
        target_type: notif.target_type,
        target_id: notif.target_id,
        parent_type: notif.parent_type,
        parent_id: notif.parent_id,
        read: not is_nil(notif.read_at),
        latest_at: notif.inserted_at,
        count: 1
      }
    end)
    |> Enum.sort_by(& &1.latest_at, {:desc, NaiveDateTime})
  end
end
