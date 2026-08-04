defmodule OGrupoDeEstudos.Workshops.WaitlistQuery do
  @moduledoc "Reads of the waitlist."

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.WaitlistEntry

  @doc "The waitlist in arrival order, with display data."
  @spec list_for_workshop(Ecto.UUID.t()) :: [map()]
  def list_for_workshop(workshop_id) do
    from(e in WaitlistEntry,
      join: u in assoc(e, :user),
      where: e.workshop_id == ^workshop_id,
      order_by: [asc: e.inserted_at],
      select: %{
        id: e.id,
        user_id: u.id,
        name: u.name,
        username: u.username,
        avatar_path: u.avatar_path,
        waiting_since: e.inserted_at
      }
    )
    |> Repo.all()
  end

  @doc "How many people are waiting. It is the number that measures pent-up demand."
  @spec count(Ecto.UUID.t()) :: non_neg_integer()
  def count(workshop_id) do
    from(e in WaitlistEntry, where: e.workshop_id == ^workshop_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Where in the waitlist the person is, counting from 1. `nil` when not in it.

  It counts whoever arrived earlier: the same order `list_for_workshop/1` shows.
  """
  @spec position(Ecto.UUID.t(), Ecto.UUID.t() | nil) :: pos_integer() | nil
  def position(_workshop_id, nil), do: nil

  def position(workshop_id, user_id) do
    case get(workshop_id, user_id) do
      nil -> nil
      entry -> antes_de(workshop_id, entry.inserted_at) + 1
    end
  end

  defp antes_de(workshop_id, momento) do
    from(e in WaitlistEntry,
      where: e.workshop_id == ^workshop_id and e.inserted_at < ^momento
    )
    |> Repo.aggregate(:count)
  end

  @doc "A entrada desta pessoa nesta fila, ou nil."
  @spec get(Ecto.UUID.t(), Ecto.UUID.t()) :: WaitlistEntry.t() | nil
  def get(workshop_id, user_id) do
    Repo.get_by(WaitlistEntry, workshop_id: workshop_id, user_id: user_id)
  end

  @doc "Whoever has waited longest, which is who has a claim on the seat."
  @spec first_in_line(Ecto.UUID.t()) :: WaitlistEntry.t() | nil
  def first_in_line(workshop_id) do
    from(e in WaitlistEntry,
      where: e.workshop_id == ^workshop_id,
      order_by: [asc: e.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc "Ids of the workshops the person is waiting for."
  @spec workshop_ids_for_user(Ecto.UUID.t()) :: [Ecto.UUID.t()]
  def workshop_ids_for_user(user_id) do
    from(e in WaitlistEntry, where: e.user_id == ^user_id, select: e.workshop_id)
    |> Repo.all()
  end
end
