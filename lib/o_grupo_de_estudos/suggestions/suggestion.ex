defmodule OGrupoDeEstudos.Suggestions.Suggestion do
  use Ecto.Schema

  @type t :: %__MODULE__{}
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_fields ~w(name note category_id)

  schema "suggestions" do
    field :target_type, Ecto.Enum, values: [:step, :connection]
    field :target_id, :binary_id
    field :action, Ecto.Enum, values: [:edit_field, :create_connection, :remove_connection]
    field :field, :string
    field :old_value, :string
    field :new_value, :string
    field :status, Ecto.Enum, values: [:pending, :approved, :rejected], default: :pending
    field :reviewed_at, :utc_datetime

    belongs_to :user, OGrupoDeEstudos.Accounts.User
    belongs_to :reviewed_by, OGrupoDeEstudos.Accounts.User

    timestamps()
  end

  @doc "Fields a user may suggest edits for."
  def suggestible_fields, do: @valid_fields

  @doc "Safely converts a suggestible field name to its schema atom."
  @spec field_atom(String.t() | nil) :: {:ok, atom()} | :error
  def field_atom("name"), do: {:ok, :name}
  def field_atom("note"), do: {:ok, :note}
  def field_atom("category_id"), do: {:ok, :category_id}
  def field_atom(_other), do: :error

  def changeset(suggestion, attrs) do
    suggestion
    |> cast(attrs, [:target_type, :target_id, :action, :field, :old_value, :new_value, :user_id])
    |> validate_required([:target_type, :target_id, :action, :user_id])
    |> validate_field_when_edit()
    |> foreign_key_constraint(:user_id)
  end

  def review_changeset(suggestion, attrs) do
    suggestion
    |> cast(attrs, [:status, :reviewed_by_id, :reviewed_at])
    |> validate_required([:status, :reviewed_by_id, :reviewed_at])
    |> foreign_key_constraint(:reviewed_by_id)
  end

  defp validate_field_when_edit(changeset) do
    action = get_field(changeset, :action)

    if action == :edit_field do
      changeset
      |> validate_required([:field, :new_value])
      |> validate_inclusion(:field, @valid_fields)
    else
      changeset
    end
  end
end
