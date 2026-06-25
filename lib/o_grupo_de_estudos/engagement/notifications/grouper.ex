defmodule OGrupoDeEstudos.Engagement.Notifications.Grouper do
  @moduledoc """
  Transforms raw notifications into display-ready grouped maps.

  Notifications sharing the same `group_key` collapse into a single entry
  (Instagram-style): several people performing the same action on the same
  target become one row with multiple actors ("João e mais 3 curtiram o passo").

  Within a group, actors are ordered newest-first and de-duplicated, so the
  primary actor is whoever acted most recently. A group counts as unread while
  any notification inside it is unread.
  """

  def group(notifications) do
    notifications
    |> Enum.group_by(& &1.group_key)
    |> Enum.map(fn {_key, group} -> build_entry(group) end)
    |> Enum.sort_by(& &1.latest_at, {:desc, NaiveDateTime})
  end

  defp build_entry(group) do
    [latest | _] = sorted = Enum.sort_by(group, & &1.inserted_at, {:desc, NaiveDateTime})
    distinct = Enum.uniq_by(sorted, & &1.actor_id)

    %{
      id: latest.id,
      action: latest.action,
      actors: Enum.map(distinct, & &1.actor_id),
      actors_data: Enum.map(distinct, & &1.actor),
      target_type: latest.target_type,
      target_id: latest.target_id,
      parent_type: latest.parent_type,
      parent_id: latest.parent_id,
      read: Enum.all?(group, &(not is_nil(&1.read_at))),
      latest_at: latest.inserted_at,
      count: length(distinct)
    }
  end
end
