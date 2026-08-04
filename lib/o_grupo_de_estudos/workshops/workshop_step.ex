defmodule OGrupoDeEstudos.Workshops.WorkshopStep do
  @moduledoc """
  Passo do acervo que foi dado num workshop.

  Quem administra monta a lista: curadoria por like foi considerada e
  descartada, porque ordenar por voto resolve com muito mais peça um problema
  que a permissão já resolve.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias OGrupoDeEstudos.Encyclopedia.Step
  alias OGrupoDeEstudos.Workshops.Workshop

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workshop_steps" do
    belongs_to :workshop, Workshop
    belongs_to :step, Step

    field :position, :integer, default: 0

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(workshop_step, attrs) do
    workshop_step
    |> cast(attrs, [:workshop_id, :step_id, :position])
    |> validate_required([:workshop_id, :step_id])
    |> unique_constraint([:workshop_id, :step_id])
    |> foreign_key_constraint(:workshop_id)
    |> foreign_key_constraint(:step_id)
  end
end
