defmodule OGrupoDeEstudos.Accounts.User do
  @moduledoc """
  Schema de usuário da plataforma.

  The role (`role`) defines the access level:
  - `"user"` — access to the encyclopedia (default)
  - `"admin"` — access to the encyclopedia + wip content + admin panel

  Promotion to admin is done directly in the database — no interface.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_roles ~w(user admin)
  @valid_states ~w(AC AL AM AP BA CE DF ES GO MA MG MS MT PA PB PE PI PR RJ RN RO RR RS SC SE SP TO)
  @min_password 8

  schema "users" do
    field :username, :string
    field :email, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :role, :string, default: "user"
    field :confirmation_token, :string
    field :confirmed_at, :naive_datetime
    field :name, :string
    field :country, :string, default: "BR"
    field :state, :string
    field :city, :string
    field :bio, :string
    field :instagram, :string
    field :avatar_path, :string

    timestamps()
  end

  @doc "Changeset for new user registration."
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :username,
      :email,
      :password,
      :role,
      :confirmation_token,
      :name,
      :country,
      :state,
      :city
    ])
    |> validate_required([:username, :email, :password, :name, :country, :city])
    |> sanitize_username()
    |> validate_name_has_two_words()
    |> validate_length(:username, min: 3, max: 30)
    |> validate_format(:username, ~r/^[a-z0-9_]+$/,
      message: "use apenas letras minúsculas, números e _"
    )
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "formato inválido")
    |> validate_length(:city, min: 2, message: "informe a cidade")
    |> validate_state_for_brazil()
    |> validate_length(:password, min: @min_password)
    |> validate_inclusion(:role, @valid_roles)
    |> unique_constraint(:username, message: "nome de usuário já existe")
    |> unique_constraint(:email, message: "email já cadastrado")
    |> hash_password()
  end

  @doc "Changeset for updating profile fields."
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:bio, :instagram, :avatar_path, :name, :username, :country, :state, :city])
    |> sanitize_username()
    |> validate_length(:bio, max: 2000)
    |> validate_length(:instagram, max: 100)
    |> validate_required([:name, :username])
    |> validate_name_has_two_words()
    |> validate_length(:username, min: 3, max: 30)
    |> validate_format(:username, ~r/^[a-z0-9_]+$/,
      message: "use apenas letras minúsculas, números e _"
    )
    |> validate_state_for_brazil()
    |> unique_constraint(:username, message: "nome de usuário já existe")
  end

  @doc "Changeset that marks the email as confirmed and invalidates the token."
  def confirmation_changeset(user) do
    utc_now = NaiveDateTime.utc_now()
    now = NaiveDateTime.truncate(utc_now, :second)
    change(user, confirmed_at: now, confirmation_token: nil)
  end

  defp sanitize_username(changeset) do
    case get_change(changeset, :username) do
      nil ->
        changeset

      username ->
        put_change(
          changeset,
          :username,
          username |> String.trim_leading("@") |> String.downcase()
        )
    end
  end

  defp validate_name_has_two_words(changeset) do
    case get_change(changeset, :name) do
      nil ->
        changeset

      name ->
        words = name |> String.trim() |> String.split(~r/\s+/)

        if length(words) >= 2 do
          changeset
        else
          add_error(changeset, :name, "informe nome e sobrenome")
        end
    end
  end

  defp validate_state_for_brazil(changeset) do
    country = get_field(changeset, :country)

    if country == "BR" do
      changeset
      |> validate_required([:state], message: "selecione um estado")
      |> validate_inclusion(:state, @valid_states, message: "selecione um estado válido")
    else
      changeset
    end
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      password -> put_change(changeset, :password_hash, Argon2.hash_pwd_salt(password))
    end
  end
end
