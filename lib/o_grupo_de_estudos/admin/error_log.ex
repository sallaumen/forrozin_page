defmodule OGrupoDeEstudos.Admin.ErrorLog do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "error_logs" do
    field :level, :string
    field :message, :string
    field :source, :string
    field :stacktrace, :string
    field :metadata, :map, default: %{}
    timestamps(updated_at: false)
  end
end
