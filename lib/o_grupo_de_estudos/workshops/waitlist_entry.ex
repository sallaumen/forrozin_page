defmodule OGrupoDeEstudos.Workshops.WaitlistEntry do
  @moduledoc """
  Lugar na fila de espera de um workshop lotado.

  A posição não é guardada: é a ordem de chegada (`inserted_at`). Guardar
  número exigiria renumerar a fila inteira a cada saída, e a fila muda mais do
  que é lida.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Workshops.Workshop

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workshop_waitlist_entries" do
    belongs_to :workshop, Workshop
    belongs_to :user, User

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:workshop_id, :user_id])
    |> validate_required([:workshop_id, :user_id])
    |> unique_constraint([:workshop_id, :user_id])
    |> foreign_key_constraint(:workshop_id)
    |> foreign_key_constraint(:user_id)
  end
end
