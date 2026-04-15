defmodule Forrozin.Accounts do
  @moduledoc """
  Action context responsible for users and authentication.
  """

  alias Forrozin.Accounts.User
  alias Forrozin.Repo

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

  @doc "Checks if the user has the admin role."
  def admin?(%User{role: "admin"}), do: true
  def admin?(_), do: false

  @doc "Returns the user's first name."
  def first_name(%User{name: name}) when is_binary(name), do: name |> String.split(" ") |> hd()
  def first_name(%User{username: u}), do: u

  @doc "Finds a user by username."
  def get_user_by_username(username), do: Repo.get_by(User, username: username)
end
