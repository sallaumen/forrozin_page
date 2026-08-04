defmodule OGrupoDeEstudos.Accounts do
  @moduledoc """
  Action context responsible for users and authentication.
  """

  alias OGrupoDeEstudos.Accounts.{AdminIdsCache, User, UserQuery}
  alias OGrupoDeEstudos.Metadata
  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Workers.{SendConfirmationEmail, SendPasswordResetEmail}

  @doc """
  Registers a new user and enqueues the welcome + confirmation email.

  The user is created *without* `confirmed_at`: they can use the app
  immediately, but a gentle banner reminds them to confirm. Confirmation
  only gates password-recovery; it is never blocking.

  Returns `{:ok, user}` or `{:error, changeset}`.
  """
  def register_user(attrs) do
    changeset =
      %User{}
      |> User.registration_changeset(attrs)

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
  def validate_confirmation_token(token) do
    case Repo.get_by(User, confirmation_token: token) do
      nil ->
        {:error, :invalid_token}

      user ->
        user |> User.confirmation_changeset() |> Repo.update()
    end
  end

  @doc "Returns `true` if the user has confirmed their email."
  def email_confirmed?(%User{confirmed_at: confirmed_at}), do: confirmed_at != nil
  def email_confirmed?(_), do: false

  @doc """
  Authenticates a user by username or email, plus password.

  An identifier containing `@` (after stripping a decorative leading `@`)
  is treated as an email; anything else as a username.

  Returns `{:ok, user}` if credentials are valid,
  `{:error, :invalid_credentials}` otherwise.

  Always runs password verification to prevent timing attacks.
  """
  def check_credentials(identifier, password) do
    identifier
    |> normalize_identifier()
    |> find_user_by_identifier()
    |> verify_password(password)
  end

  defp normalize_identifier(identifier) do
    identifier |> String.trim() |> String.trim_leading("@") |> String.downcase()
  end

  defp find_user_by_identifier(identifier) do
    case String.split(identifier, "@", parts: 2) do
      [_local, _domain] -> Repo.get_by(User, email: identifier)
      [username] -> Repo.get_by(User, username: username)
    end
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

  @doc """
  Logs in or registers a user coming from Google sign-in.

  Resolution order: by google id (returning user), then by email (links the
  google account to the existing user, confirming the email), then a fresh
  registration with a username derived from the email and a random password.

  Returns `{:ok, user, :existing | :linked | :registered}` or
  `{:error, changeset}`.
  """
  def login_or_register_google_user(%{google_id: google_id} = profile) do
    case Repo.get_by(User, google_id: google_id) do
      %User{} = user -> {:ok, user, :existing}
      nil -> link_or_register_google_user(profile)
    end
  end

  defp link_or_register_google_user(profile) do
    case get_user_by_email(profile.email) do
      %User{} = user -> link_google_user(user, profile.google_id)
      nil -> register_google_user(profile)
    end
  end

  defp link_google_user(user, google_id) do
    case user |> User.link_google_changeset(google_id) |> Repo.update() do
      {:ok, linked} -> {:ok, linked, :linked}
      error -> error
    end
  end

  defp register_google_user(profile) do
    attrs = %{
      username: derive_username(profile.email),
      email: profile.email,
      name: profile.name,
      google_id: profile.google_id
    }

    case %User{} |> User.google_registration_changeset(attrs) |> Repo.insert() do
      {:ok, user} -> {:ok, user, :registered}
      error -> error
    end
  end

  defp derive_username(email) do
    base = username_base(email)

    [base]
    |> Stream.concat(Stream.map(1..999, &"#{base}#{&1}"))
    |> Enum.find(&username_available?/1)
  end

  defp username_base(email) do
    base =
      email
      |> String.split("@", parts: 2)
      |> hd()
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9_]/, "")
      |> String.slice(0, 24)

    if String.length(base) >= 3, do: base, else: "forrozeiro"
  end

  defp username_available?(username), do: get_user_by_username(username) == nil

  @doc "Finds a user by id. Returns `nil` if not found."
  def get_user_by_id(id) do
    Repo.get(User, id)
  end

  @doc "Finds a user by invite slug."
  def get_user_by_invite_slug(invite_slug), do: Repo.get_by(User, invite_slug: invite_slug)

  @doc "Checks if the user has the admin role."
  def admin?(%User{role: :admin}), do: true
  def admin?(_), do: false

  @doc "Whether the profile has the location data asked at signup."
  defdelegate profile_complete?(user), to: User

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
    if String.length(term) < 2 do
      []
    else
      UserQuery.search(term, opts)
    end
  end

  @doc "Searches teachers by name or username. Accepts `exclude_id:`."
  def search_teachers(term, opts \\ []) when is_binary(term) do
    UserQuery.search_teachers(term, opts)
  end

  @doc "Admin user ids (cached node-locally; see AdminIdsCache)."
  defdelegate list_admin_ids, to: AdminIdsCache, as: :get

  @doc "Batch-loads lightweight user summaries (id, username, name, avatar) by id."
  defdelegate list_user_summaries(ids), to: UserQuery, as: :summaries_by_ids

  @doc "Returns a list of all usernames (for sitemap generation)."
  defdelegate list_all_usernames, to: UserQuery, as: :list_usernames

  @doc "Finds a user by email. Returns nil if not found."
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(String.trim(email)))
  end

  def get_user_by_email(_), do: nil

  @doc """
  Backfills stored emails to their lowercase, trimmed form.

  Returns `{normalized_count, conflict_emails}`. An email whose lowercase
  form already belongs to another user is left untouched and reported for
  manual review.
  """
  def normalize_all_emails do
    {:ok, result} =
      Repo.transaction(fn ->
        UserQuery.stream_mixed_case_emails()
        |> Enum.reduce({0, []}, &normalize_stored_email/2)
      end)

    result
  end

  defp normalize_stored_email(user, {count, conflicts}) do
    normalized = user.email |> String.trim() |> String.downcase()

    case get_user_by_email(normalized) do
      nil ->
        user |> Ecto.Changeset.change(email: normalized) |> Repo.update!()
        {count + 1, conflicts}

      _other_user ->
        {count, [user.email | conflicts]}
    end
  end

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
        |> SendPasswordResetEmail.new()
        |> Oban.insert()

        :ok
    end
  end

  @doc """
  Toggles the user's dark mode preference.

  Returns `{:ok, updated_user}` or `{:error, changeset}`.
  """
  def toggle_dark_mode(%User{} = user) do
    user
    |> Ecto.Changeset.change(%{dark_mode: !user.dark_mode})
    |> Repo.update()
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
