defmodule OGrupoDeEstudos.Workshops.JoinRequest do
  @moduledoc """
  Pedido para entrar num workshop privado.

  Workshop privado não é secreto: ele aparece na agenda como qualquer outro,
  com título, data e preço à vista. O que muda é a porta. Quem quer entrar
  pede, e quem organiza decide.

  Aprovar já matricula: a pessoa que pediu já disse o que queria, e uma
  segunda confirmação seria burocracia para dizer a mesma coisa.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Workshops.Workshop

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workshop_join_requests" do
    belongs_to :workshop, Workshop
    belongs_to :user, User
    belongs_to :reviewed_by, User

    field :status, Ecto.Enum, values: [:pending, :approved, :rejected], default: :pending
    field :reviewed_at, :utc_datetime

    timestamps(type: :utc_datetime_usec)
  end

  @doc "Pedido novo: nasce pendente, sem quem revisou."
  def changeset(request, attrs) do
    request
    |> cast(attrs, [:workshop_id, :user_id, :status])
    |> validate_required([:workshop_id, :user_id])
    |> unique_constraint([:workshop_id, :user_id])
    |> foreign_key_constraint(:workshop_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc "Resposta de quem organiza, com carimbo de quem decidiu e quando."
  def review_changeset(request, status, %User{id: reviewer_id}) do
    change(request, %{
      status: status,
      reviewed_by_id: reviewer_id,
      reviewed_at: DateTime.utc_now(:second)
    })
  end
end
