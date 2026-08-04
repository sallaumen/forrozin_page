defmodule OGrupoDeEstudos.Workshops.JoinRequestQuery do
  @moduledoc "Leituras de `JoinRequest`."

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.JoinRequest

  @doc "Requests waiting for an answer, oldest first (the organizer queue)."
  @spec list_pending(Ecto.UUID.t()) :: [map()]
  def list_pending(workshop_id), do: listar(workshop_id, :pending)

  @doc "Pedidos do workshop em qualquer status."
  @spec list_all(Ecto.UUID.t()) :: [map()]
  def list_all(workshop_id), do: listar(workshop_id, nil)

  defp listar(workshop_id, status) do
    JoinRequest
    |> where([r], r.workshop_id == ^workshop_id)
    |> filtrar_status(status)
    |> join(:inner, [r], u in assoc(r, :user), as: :pessoa)
    |> order_by([r], asc: r.inserted_at)
    |> select([r, pessoa: u], %{
      id: r.id,
      user_id: u.id,
      name: u.name,
      username: u.username,
      avatar_path: u.avatar_path,
      city: u.city,
      status: r.status,
      requested_at: r.inserted_at
    })
    |> Repo.all()
  end

  defp filtrar_status(query, nil), do: query
  defp filtrar_status(query, status), do: where(query, [r], r.status == ^status)

  @doc "The request of a person in this workshop, or nil."
  @spec get(Ecto.UUID.t(), Ecto.UUID.t()) :: JoinRequest.t() | nil
  def get(workshop_id, user_id) do
    Repo.get_by(JoinRequest, workshop_id: workshop_id, user_id: user_id)
  end

  @doc """
  Where the request stands: `:none`, `:pending`, `:approved` or `:rejected`.

  It exists so the screen can choose between "ask to join" and "waiting" without
  loading the whole row.
  """
  @spec status(Ecto.UUID.t(), Ecto.UUID.t() | nil) :: :none | :pending | :approved | :rejected
  def status(_workshop_id, nil), do: :none

  def status(workshop_id, user_id) do
    from(r in JoinRequest,
      where: r.workshop_id == ^workshop_id and r.user_id == ^user_id,
      select: r.status
    )
    |> Repo.one()
    |> case do
      nil -> :none
      status -> status
    end
  end

  @doc "How many requests are waiting for an answer, for the panel counter."
  @spec count_pending(Ecto.UUID.t()) :: non_neg_integer()
  def count_pending(workshop_id) do
    from(r in JoinRequest, where: r.workshop_id == ^workshop_id and r.status == :pending)
    |> Repo.aggregate(:count)
  end
end
