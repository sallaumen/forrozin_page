defmodule OGrupoDeEstudos.Study.ActiveDay do
  @moduledoc """
  Marks that a user was active in the app on a given day (any page).

  Feeds the consistency count of the Study area: the day counts even without a
  diary entry, to encourage the habit of showing up. One row per `(user_id, day)`.
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
