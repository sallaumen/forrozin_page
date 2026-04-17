defmodule OGrupoDeEstudos.Suggestions.Suggestion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_target_types ~w(step connection)
  @valid_actions ~w(edit_field create_connection remove_connection)
  @valid_statuses ~w(pending approved rejected)
  @valid_fields ~w(name note category_id)

  schema "suggestions" do
    field :target_type, :string
    field :target_id, :binary_id
    field :action, :string
    field :field, :string
    field :old_value, :string
    field :new_value, :string
    field :status, :string, default: "pending"
    field :reviewed_at, :naive_datetime

    belongs_to :user, OGrupoDeEstudos.Accounts.User
    belongs_to :reviewed_by, OGrupoDeEstudos.Accounts.User

    timestamps()
  end

  def changeset(suggestion, attrs) do
    suggestion
    |> cast(attrs, [:target_type, :target_id, :action, :field, :old_value, :new_value, :user_id])
    |> validate_required([:target_type, :target_id, :action, :user_id])
    |> validate_inclusion(:target_type, @valid_target_types)
    |> validate_inclusion(:action, @valid_actions)
    |> validate_field_when_edit()
    |> foreign_key_constraint(:user_id)
  end

  def review_changeset(suggestion, attrs) do
    suggestion
    |> cast(attrs, [:status, :reviewed_by_id, :reviewed_at])
    |> validate_required([:status, :reviewed_by_id, :reviewed_at])
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:reviewed_by_id)
  end

  defp validate_field_when_edit(changeset) do
    action = get_field(changeset, :action)

    if action == "edit_field" do
      changeset
      |> validate_required([:field, :new_value])
      |> validate_inclusion(:field, @valid_fields)
    else
      changeset
    end
  end
end
