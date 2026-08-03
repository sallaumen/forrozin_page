defmodule OGrupoDeEstudos.Workshops.WaitlistQuery do
  @moduledoc "Leituras da fila de espera."

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.WaitlistEntry

  @doc "A fila em ordem de chegada, com dados de exibição."
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

  @doc "Quantas pessoas esperando. É o número que mede demanda reprimida."
  @spec count(Ecto.UUID.t()) :: non_neg_integer()
  def count(workshop_id) do
    from(e in WaitlistEntry, where: e.workshop_id == ^workshop_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Em que lugar da fila a pessoa está, contando de 1. `nil` se não está.

  Conta quem chegou antes: é a mesma ordem que `list_for_workshop/1` mostra.
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

  @doc "Quem está esperando há mais tempo, que é quem tem direito à vaga."
  @spec first_in_line(Ecto.UUID.t()) :: WaitlistEntry.t() | nil
  def first_in_line(workshop_id) do
    from(e in WaitlistEntry,
      where: e.workshop_id == ^workshop_id,
      order_by: [asc: e.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  @doc "Ids dos workshops em que a pessoa está esperando."
  @spec workshop_ids_for_user(Ecto.UUID.t()) :: [Ecto.UUID.t()]
  def workshop_ids_for_user(user_id) do
    from(e in WaitlistEntry, where: e.user_id == ^user_id, select: e.workshop_id)
    |> Repo.all()
  end
end
