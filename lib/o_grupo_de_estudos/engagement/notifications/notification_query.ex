defmodule OGrupoDeEstudos.Engagement.Notifications.NotificationQuery do
  @moduledoc """
  Query reducers for the Notification schema.

  Provides paginated listing and unread counting for a user's notification feed.
  Ordering: unread first (read_at NULLS FIRST), then newest first.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Engagement.Notifications.Notification
  alias OGrupoDeEstudos.Repo

  @type list_opt :: {:limit, non_neg_integer()} | {:offset, non_neg_integer()}
  @type opts :: [list_opt()]

  @doc """
  Returns notifications for the given user, ordered unread-first then by newest.

  The limit counts **subjects** (`group_key`), not rows: since the `Grouper`
  collapses each subject into a single entry, cutting by row would let one burst
  (a workshop with 100 enrollments) take the whole list and hide the rest. Every
  row of the chosen subjects comes along, otherwise the "and 99 more" would be
  counted over a sample.

  ## Options

  - `:limit` for the maximum number of subjects (default 20)
  - `:offset` for the offset, also in subjects (default 0)
  """
  @spec list_for_user(Ecto.UUID.t(), opts()) :: [Notification.t()]
  def list_for_user(user_id, opts \\ []) do
    keys = recent_group_keys(user_id, opts)

    from(n in Notification,
      where: n.user_id == ^user_id and n.group_key in ^keys,
      order_by: [asc_nulls_first: n.read_at, desc: n.inserted_at],
      preload: [:actor]
    )
    |> Repo.all()
  end

  # A subject counts as unread while any of its rows is unread, and takes the
  # date of its most recent row. In Postgres false < true, so "has unread"
  # sorts first.
  defp recent_group_keys(user_id, opts) do
    from(n in Notification,
      where: n.user_id == ^user_id,
      group_by: n.group_key,
      select: n.group_key,
      order_by: [
        asc: fragment("count(*) FILTER (WHERE ? IS NULL) = 0", n.read_at),
        desc: max(n.inserted_at)
      ],
      limit: ^Keyword.get(opts, :limit, 20),
      offset: ^Keyword.get(opts, :offset, 0)
    )
    |> Repo.all()
  end

  @doc "Returns the count of unread notifications, optionally filtered by `action:`."
  @spec unread_count(Ecto.UUID.t(), [{:action, atom()}]) :: non_neg_integer()
  def unread_count(user_id, opts \\ []) do
    from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at))
    |> filter_action(opts[:action])
    |> Repo.aggregate(:count)
  end

  defp filter_action(query, nil), do: query
  defp filter_action(query, action), do: where(query, [n], n.action == ^action)

  @doc "Composable scope: unread notifications of a user."
  @spec unread_by_user(Ecto.UUID.t()) :: Ecto.Query.t()
  def unread_by_user(user_id) do
    from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at))
  end

  @doc "Composable scope: one specific unread notification of a user."
  @spec unread_by_user(Ecto.UUID.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def unread_by_user(user_id, notification_id) do
    user_id
    |> unread_by_user()
    |> where([n], n.id == ^notification_id)
  end
end
