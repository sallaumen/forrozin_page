defmodule OGrupoDeEstudos.Workshops.WorkshopAdmin do
  @moduledoc """
  Co-organizador de um workshop.

  O criador (`Workshop.organizer_id`) não tem linha aqui: ele é dono por
  construção. Esta tabela guarda só quem foi promovido depois.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Workshops.Workshop

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workshop_admins" do
    belongs_to :workshop, Workshop
    belongs_to :user, User
    belongs_to :invited_by, User

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(admin, attrs) do
    admin
    |> cast(attrs, [:workshop_id, :user_id, :invited_by_id])
    |> validate_required([:workshop_id, :user_id])
    |> unique_constraint([:workshop_id, :user_id])
    |> foreign_key_constraint(:workshop_id)
    |> foreign_key_constraint(:user_id)
  end
end
