defmodule Forrozin.Accounts do
  @moduledoc """
  Action context responsible for users and authentication.
  """

  alias Forrozin.Accounts.User
  alias Forrozin.Repo
  alias Forrozin.Workers.SendConfirmationEmail

  @doc """
  Registers a new user and enqueues the confirmation email.

  Returns `{:ok, user}` or `{:error, changeset}`.
  """
  def register_user(attrs) do
    token = generate_token()

    changeset =
      %User{}
      |> User.registration_changeset(attrs)
      |> Ecto.Changeset.put_change(:confirmation_token, token)

    case Repo.insert(changeset) do
      {:ok, user} ->
        %{user_id: user.id}
        |> SendConfirmationEmail.new()
        |> Oban.insert()

        {:ok, user}

      error ->
        error
    end
  end

  @doc """
  Confirms a user's email by token.

  Returns `{:ok, user}` or `{:error, :invalid_token}`.
  """
  def confirm_email(token) do
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
  def authenticate_user(username, password) do
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

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
