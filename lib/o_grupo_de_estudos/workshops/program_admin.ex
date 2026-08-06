defmodule OGrupoDeEstudos.Workshops.ProgramAdmin do
  @moduledoc """
  Co-organizer of a program.

  The creator (`WorkshopProgram.owner_id`) has no row here: they own it by
  construction. This table stores only whoever was promoted afterwards.

  Administering the program is not administering the workshops inside it. A
  festival gathers classes from several teachers, and the money of each class
  belongs to whoever runs it: access to a workshop keeps being its own
  invitation, through `WorkshopAdmin`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Workshops.WorkshopProgram

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "program_admins" do
    belongs_to :program, WorkshopProgram
    belongs_to :user, User
    belongs_to :invited_by, User

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(admin, attrs) do
    admin
    |> cast(attrs, [:program_id, :user_id, :invited_by_id])
    |> validate_required([:program_id, :user_id])
    |> unique_constraint([:program_id, :user_id])
    |> foreign_key_constraint(:program_id)
    |> foreign_key_constraint(:user_id)
  end
end
