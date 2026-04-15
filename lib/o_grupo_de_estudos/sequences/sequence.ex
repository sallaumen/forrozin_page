defmodule OGrupoDeEstudos.Sequences.Sequence do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sequences" do
    field :name, :string
    field :allow_repeats, :boolean, default: false
    field :public, :boolean, default: true
    field :description, :string
    field :video_url, :string
    field :deleted_at, :naive_datetime

    belongs_to :user, OGrupoDeEstudos.Accounts.User
    has_many :sequence_steps, OGrupoDeEstudos.Sequences.SequenceStep, preload_order: [asc: :position]

    timestamps()
  end

  def changeset(sequence, attrs) do
    sequence
    |> cast(attrs, [
      :name,
      :user_id,
      :allow_repeats,
      :public,
      :description,
      :video_url,
      :deleted_at
    ])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_url()
    |> foreign_key_constraint(:user_id)
  end

  defp validate_url(changeset) do
    case get_change(changeset, :video_url) do
      nil -> changeset
      "" -> changeset
      _ -> validate_format(changeset, :video_url, ~r/^https?:\/\//, message: "URL inválida")
    end
  end
end
