defmodule OGrupoDeEstudos.StartupScriptRecord do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "data_migrations" do
    field :name, :string
    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec
    field :result, :string, default: "pending"

    timestamps(type: :utc_datetime_usec)
  end
end
