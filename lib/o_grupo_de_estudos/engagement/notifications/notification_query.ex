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

  ## Options

  - `:limit` — max results (default 20)
  - `:offset` — pagination offset (default 0)
  """
  @spec list_for_user(Ecto.UUID.t(), opts()) :: [Notification.t()]
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

  @doc "Returns the count of unread notifications, optionally filtered by `action:`."
  @spec unread_count(Ecto.UUID.t(), [{:action, String.t()}]) :: non_neg_integer()
  def unread_count(user_id, opts \\ []) do
    from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at))
    |> filter_action(opts[:action])
    |> Repo.aggregate(:count)
  end

  defp filter_action(query, nil), do: query
  defp filter_action(query, action), do: where(query, [n], n.action == ^action)
end
