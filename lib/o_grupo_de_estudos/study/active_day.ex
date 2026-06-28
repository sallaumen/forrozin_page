defmodule OGrupoDeEstudos.Study.ActiveDay do
  @moduledoc """
  Marca que um usuário esteve ativo no app num determinado dia (qualquer página).

  Alimenta a consistência da área de Estudos: o dia conta mesmo sem registro de
  diário, pra incentivar o hábito de aparecer. Um registro por `(user_id, day)`.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "study_active_days" do
    field :day, :date

    belongs_to :user, OGrupoDeEstudos.Accounts.User

    timestamps(type: :utc_datetime_usec)
  end
end
