defmodule OGrupoDeEstudos.Accounts.User do
  @moduledoc """
  Platform user schema.

  The role defines the access level:
  - `"user"` gets the encyclopedia (default)
  - `"admin"` gets the encyclopedia plus wip content and the admin panel

  Promotion to admin happens directly in the database, with no interface.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_states ~w(AC AL AM AP BA CE DF ES GO MA MG MS MT PA PB PE PI PR RJ RN RO RR RS SC SE SP TO)
  @min_password 8

  @type t :: %__MODULE__{}

  # Keep credentials out of logs, crash reports and inspect output. The app
  # persists exceptions via Admin.ErrorLogger, which would otherwise capture them.
  @derive {Inspect, except: [:password, :password_hash, :confirmation_token]}
  schema "users" do
    field :username, :string
    field :email, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :role, Ecto.Enum, values: [:user, :admin], default: :user
    field :confirmation_token, :string
    field :confirmed_at, :utc_datetime
    field :name, :string
    field :country, :string, default: "BR"
    field :state, :string
    field :city, :string
    field :bio, :string
    field :instagram, :string
    field :avatar_path, :string
    field :is_teacher, :boolean, default: false
    field :google_id, :string
    field :invite_slug, :string
    field :last_seen_at, :utc_datetime
    field :last_login_at, :utc_datetime
    field :dark_mode, :boolean, default: false

    timestamps()
  end

  @doc "Changeset for new user registration."
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :username,
      :email,
      :password,
      :name,
      :country,
      :state,
      :city,
      :is_teacher
    ])
    |> validate_required([:username, :email, :password, :name, :country, :city])
    |> sanitize_username()
    |> normalize_email()
    |> validate_name_has_two_words()
    |> validate_length(:username, min: 3, max: 30)
    |> validate_format(:username, ~r/^[a-z0-9_]+$/,
      message: "use apenas letras minúsculas, números e _"
    )
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "formato inválido")
    |> validate_length(:city, min: 2, message: "informe a cidade")
    |> validate_state_for_brazil()
    |> validate_length(:password, min: @min_password)
    |> put_invite_slug()
    |> unique_constraint(:username, message: "nome de usuário já existe")
    |> unique_constraint(:email, message: "email já cadastrado")
    |> unique_constraint(:invite_slug, message: "link de convite já existe")
    |> hash_password()
    |> put_confirmation_token()
  end

  @doc """
  Changeset for a user registered through Google sign-in.

  City, state and the two-word name rule are not required here: the profile
  is completed later, nudged from the settings page. A random password is
  generated so password login (and recovery) keeps working as a fallback.
  """
  def google_registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :name, :google_id])
    |> validate_required([:username, :email, :name, :google_id])
    |> sanitize_username()
    |> normalize_email()
    |> validate_length(:username, min: 3, max: 30)
    |> validate_format(:username, ~r/^[a-z0-9_]+$/,
      message: "use apenas letras minúsculas, números e _"
    )
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "formato inválido")
    |> put_invite_slug()
    |> put_random_password()
    |> put_confirmed_now()
    |> unique_constraint(:username, message: "nome de usuário já existe")
    |> unique_constraint(:email, message: "email já cadastrado")
    |> unique_constraint(:invite_slug, message: "link de convite já existe")
    |> unique_constraint(:google_id)
  end

  @doc "Changeset linking a Google account, confirming the email if needed."
  def link_google_changeset(user, google_id) do
    user
    |> change(google_id: google_id)
    |> put_confirmed_now()
    |> unique_constraint(:google_id)
  end

  @doc "Whether the profile has the location data asked at signup."
  def profile_complete?(%__MODULE__{country: "BR"} = user) do
    filled?(user.city) and filled?(user.state)
  end

  def profile_complete?(%__MODULE__{} = user), do: filled?(user.city)

  @doc "Changeset for updating profile fields."
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [
      :bio,
      :instagram,
      :avatar_path,
      :name,
      :username,
      :country,
      :state,
      :city,
      :is_teacher,
      :dark_mode
    ])
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
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(user, confirmed_at: now, confirmation_token: nil)
  end

  @doc "Changeset for resetting the password."
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8)
    |> hash_password()
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

  defp normalize_email(changeset) do
    case get_change(changeset, :email) do
      nil -> changeset
      email -> put_change(changeset, :email, email |> String.trim() |> String.downcase())
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

  defp put_invite_slug(changeset) do
    case {get_field(changeset, :invite_slug), get_field(changeset, :username)} do
      {nil, username} when is_binary(username) and username != "" ->
        put_change(changeset, :invite_slug, "prof-#{username}")

      {"", username} when is_binary(username) and username != "" ->
        put_change(changeset, :invite_slug, "prof-#{username}")

      _ ->
        changeset
    end
  end

  defp put_random_password(changeset) do
    random_password = Base.encode64(:crypto.strong_rand_bytes(32))
    put_change(changeset, :password_hash, Argon2.hash_pwd_salt(random_password))
  end

  defp put_confirmed_now(changeset) do
    case get_field(changeset, :confirmed_at) do
      nil ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        put_change(changeset, :confirmed_at, now)

      _confirmed_at ->
        changeset
    end
  end

  defp filled?(nil), do: false
  defp filled?(value), do: String.trim(value) != ""

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      password -> put_change(changeset, :password_hash, Argon2.hash_pwd_salt(password))
    end
  end

  defp put_confirmation_token(changeset) do
    if get_change(changeset, :email) do
      put_change(
        changeset,
        :confirmation_token,
        :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
      )
    else
      changeset
    end
  end
end
