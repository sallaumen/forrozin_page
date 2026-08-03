defmodule OGrupoDeEstudos.Workshops.WorkshopInvite do
  @moduledoc """
  Convite para um workshop privado.

  Convidar já libera: não há estado pendente. Quem foi convidado enxerga a
  página e decide se se inscreve, que é a confirmação de verdade. Um aceite
  separado seria uma etapa a mais para dizer a mesma coisa.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Workshops.Workshop

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workshop_invites" do
    belongs_to :workshop, Workshop
    belongs_to :user, User
    belongs_to :invited_by, User

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(invite, attrs) do
    invite
    |> cast(attrs, [:workshop_id, :user_id, :invited_by_id])
    |> validate_required([:workshop_id, :user_id])
    |> unique_constraint([:workshop_id, :user_id])
    |> foreign_key_constraint(:workshop_id)
    |> foreign_key_constraint(:user_id)
  end
end
