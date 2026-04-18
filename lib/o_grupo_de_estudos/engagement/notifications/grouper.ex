defmodule OGrupoDeEstudos.Engagement.Notifications.Grouper do
  @moduledoc "Groups raw notifications into Instagram-style display groups."

  def group(notifications) do
    notifications
    |> Enum.group_by(& &1.group_key)
    |> Enum.map(fn {_key, group} ->
      latest = Enum.max_by(group, & &1.inserted_at, NaiveDateTime)

      %{
        id: latest.id,
        action: latest.action,
        actors: group |> Enum.map(& &1.actor_id) |> Enum.uniq(),
        actors_data: group |> Enum.map(& &1.actor) |> Enum.uniq_by(& &1.id),
        target_type: latest.target_type,
        target_id: latest.target_id,
        parent_type: latest.parent_type,
        parent_id: latest.parent_id,
        read: Enum.all?(group, &(not is_nil(&1.read_at))),
        latest_at: latest.inserted_at,
        count: length(group)
      }
    end)
    |> Enum.sort_by(& &1.latest_at, {:desc, NaiveDateTime})
  end
end
