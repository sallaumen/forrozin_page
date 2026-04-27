defmodule OGrupoDeEstudos.Accounts do
  @moduledoc """
  Action context responsible for users and authentication.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Metadata
  alias OGrupoDeEstudos.Repo

  @doc """
  Registers a new user and enqueues the confirmation email.

  Returns `{:ok, user}` or `{:error, changeset}`.
  """
  def register_user(attrs) do
    utc_now = NaiveDateTime.utc_now()
    now = NaiveDateTime.truncate(utc_now, :second)

    changeset =
      %User{}
      |> User.registration_changeset(attrs)
      |> Ecto.Changeset.put_change(:confirmed_at, now)

    Repo.insert(changeset)
  end

  @doc """
  Confirms a user's email by token.

  Returns `{:ok, user}` or `{:error, :invalid_token}`.
  """
  def validate_confirmation_token(token) do
    case Repo.get_by(User, confirmation_token: token) do
      nil -> {:error, :invalid_token}
      user -> user |> User.confirmation_changeset() |> Repo.update()
    end
  end

  @doc "Returns `true` if the user has confirmed their email."
  def email_confirmed?(%User{confirmed_at: confirmed_at}), do: confirmed_at != nil
  def email_confirmed?(_), do: false

  @doc """
  Authenticates a user by username and password.

  Returns `{:ok, user}` if credentials are valid,
  `{:error, :invalid_credentials}` otherwise.

  Always runs password verification to prevent timing attacks.
  """
  def check_credentials(username, password) do
    username = username |> String.trim_leading("@") |> String.downcase()
    user = Repo.get_by(User, username: username)
    verify_password(user, password)
  end

  defp verify_password(nil, _password) do
    Argon2.no_user_verify()
    {:error, :invalid_credentials}
  end

  defp verify_password(user, password) do
    if Argon2.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      {:error, :invalid_credentials}
    end
  end

  @doc "Finds a user by id. Returns `nil` if not found."
  def get_user_by_id(id) do
    Repo.get(User, id)
  end

  @doc "Finds a user by invite slug."
  def get_user_by_invite_slug(invite_slug), do: Repo.get_by(User, invite_slug: invite_slug)

  @doc "Checks if the user has the admin role."
  def admin?(%User{role: "admin"}), do: true
  def admin?(_), do: false

  @doc "Returns the user's first name."
  def first_name(%User{name: name}) when is_binary(name), do: name |> String.split(" ") |> hd()
  def first_name(%User{username: u}), do: u

  @doc "Finds a user by username."
  def get_user_by_username(username), do: Repo.get_by(User, username: username)

  @doc """
  Updates editable profile fields (bio, instagram, avatar_path).

  Returns `{:ok, user}` or `{:error, changeset}`.
  """
  def change_profile(user, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
  end

  def update_profile(user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Searches users by username or name (case-insensitive).
  Returns up to 5 results, excluding the given user ID.
  Requires at least 2 characters to execute.
  """
  def search_users(term, opts \\ []) when is_binary(term) do
    exclude_id = Keyword.get(opts, :exclude_id)

    if String.length(term) < 2 do
      []
    else
      term_like = "%#{String.downcase(term)}%"

      from(u in User,
        where: ilike(u.username, ^term_like) or ilike(u.name, ^term_like),
        where: u.id != ^exclude_id,
        order_by: [asc: u.username],
        limit: 5
      )
      |> Repo.all()
    end
  end

  @doc "Finds a user by email. Returns nil if not found."
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(String.trim(email)))
  end

  def get_user_by_email(_), do: nil

  @doc """
  Updates a user's password and increments the reset counter.
  Returns `{:ok, user}` or `{:error, changeset}`.
  """
  def reset_password(user, new_password) do
    result =
      user
      |> User.password_changeset(%{password: new_password})
      |> Repo.update()

    case result do
      {:ok, _} ->
        Metadata.increment(Metadata.password_reset_count_name(), "user", user.id)
        result

      error ->
        error
    end
  end

  @doc """
  Initiates password reset: generates token and enqueues email.
  Always returns :ok (does not reveal if email exists).
  """
  def request_password_reset(email, endpoint) do
    case get_user_by_email(email) do
      nil ->
        :ok

      user ->
        token = Phoenix.Token.sign(endpoint, "reset_password", user.id)
        reset_url = OGrupoDeEstudosWeb.Endpoint.url() <> "/reset-password/#{token}"

        %{user_id: user.id, reset_url: reset_url}
        |> OGrupoDeEstudos.Workers.SendPasswordResetEmail.new()
        |> Oban.insert()

        :ok
    end
  end

  @doc """
  Verifies a password reset token. Returns `{:ok, user}` or `{:error, :invalid_token}`.
  Token expires after 30 minutes (1800 seconds).
  """
  def verify_reset_token(endpoint, token) do
    case Phoenix.Token.verify(endpoint, "reset_password", token, max_age: 1800) do
      {:ok, user_id} ->
        case get_user_by_id(user_id) do
          nil -> {:error, :invalid_token}
          user -> {:ok, user}
        end

      {:error, _reason} ->
        {:error, :invalid_token}
    end
  end
end
