defmodule OGrupoDeEstudos.Admin.ErrorLog do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "error_logs" do
    field :level, Ecto.Enum,
      values: [:emergency, :alert, :critical, :error, :warning, :notice, :info, :debug]

    field :message, :string
    field :source, :string
    field :stacktrace, :string
    field :metadata, :map, default: %{}
    timestamps(updated_at: false)
  end
end
