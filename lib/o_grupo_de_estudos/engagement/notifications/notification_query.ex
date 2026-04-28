defmodule OGrupoDeEstudos.Engagement.Notifications.NotificationQuery do
  @moduledoc """
  Query reducers for the Notification schema.

  Provides paginated listing and unread counting for a user's notification feed.
  Ordering: unread first (read_at NULLS FIRST), then newest first.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias OGrupoDeEstudos.Repo

  @doc """
  Returns notifications for the given user, ordered unread-first then by newest.

  ## Options

  - `:limit` — max results (default 20)
  - `:offset` — pagination offset (default 0)
  """
  def list_for_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    from(n in Notification,
      where: n.user_id == ^user_id,
      order_by: [asc_nulls_first: n.read_at, desc: n.inserted_at],
      limit: ^limit,
      offset: ^offset,
      preload: [:actor]
    )
    |> Repo.all()
  end

  @doc "Returns the count of unread notifications for the given user."
  def unread_count(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at),
      select: count(n.id)
    )
    |> Repo.one()
  end
end
