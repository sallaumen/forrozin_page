defmodule OGrupoDeEstudos.Workshops.JoinRequestQuery do
  @moduledoc "Leituras de `JoinRequest`."

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workshops.JoinRequest

  @doc "Pedidos esperando resposta, mais antigo primeiro (a fila de quem organiza)."
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

  @doc "O pedido de uma pessoa neste workshop, ou nil."
  @spec get(Ecto.UUID.t(), Ecto.UUID.t()) :: JoinRequest.t() | nil
  def get(workshop_id, user_id) do
    Repo.get_by(JoinRequest, workshop_id: workshop_id, user_id: user_id)
  end

  @doc """
  Em que pé está o pedido: `:none`, `:pending`, `:approved` ou `:rejected`.

  Existe para a tela decidir entre "Pedir para entrar" e "Aguardando" sem
  carregar a linha inteira.
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

  @doc "Quantos pedidos esperando resposta, para o contador do painel."
  @spec count_pending(Ecto.UUID.t()) :: non_neg_integer()
  def count_pending(workshop_id) do
    from(r in JoinRequest, where: r.workshop_id == ^workshop_id and r.status == :pending)
    |> Repo.aggregate(:count)
  end
end
