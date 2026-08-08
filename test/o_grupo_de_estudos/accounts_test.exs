defmodule OGrupoDeEstudos.AccountsTest do
  use OGrupoDeEstudos.DataCase, async: true

  import Swoosh.TestAssertions

  alias OGrupoDeEstudos.Accounts

  @valid_attrs %{
    username: "novousuario",
    name: "Novo Usuário",
    email: "novo@example.com",
    password: "senhasegura",
    country: "BR",
    state: "PR",
    city: "Curitiba"
  }

  describe "normalize_all_emails/0" do
    test "downcases mixed-case stored emails" do
      user = insert_user_with_raw_email("mixedcase", "Tata@Example.COM")

      assert {1, []} = Accounts.normalize_all_emails()
      assert Repo.get(Accounts.User, user.id).email == "tata@example.com"
    end

    test "leaves already-lowercase emails untouched" do
      {:ok, user} = Accounts.register_user(@valid_attrs)

      assert {0, []} = Accounts.normalize_all_emails()
      assert Repo.get(Accounts.User, user.id).email == user.email
    end

    test "skips and reports emails that collide after downcasing" do
      {:ok, _existing} = Accounts.register_user(@valid_attrs)
      conflicting = insert_user_with_raw_email("colidente", "NOVO@example.com")

      assert {0, ["NOVO@example.com"]} = Accounts.normalize_all_emails()
      assert Repo.get(Accounts.User, conflicting.id).email == "NOVO@example.com"
    end
  end

  describe "register_user/1" do
    test "creates unconfirmed user with a confirmation token" do
      assert {:ok, user} = Accounts.register_user(@valid_attrs)

      assert user.username == "novousuario"
      assert user.email == "novo@example.com"
      assert user.role == :user
      assert user.password_hash != nil
      assert is_nil(user.confirmed_at), "user must NOT be auto-confirmed"
      assert is_binary(user.confirmation_token), "must generate a confirmation token"
    end

    test "sends welcome email with confirmation link after registration" do
      assert {:ok, user} = Accounts.register_user(@valid_attrs)

      assert_email_sent(fn email ->
        assert {_, address} = hd(email.to)
        assert address == user.email
        assert email.text_body =~ "/confirm/#{user.confirmation_token}"
      end)
    end

    test "returns error with duplicate username" do
      Accounts.register_user(@valid_attrs)

      assert {:error, changeset} =
               Accounts.register_user(%{@valid_attrs | email: "outro@example.com"})

      assert errors_on(changeset).username != []
    end

    test "returns error with duplicate email" do
      Accounts.register_user(@valid_attrs)

      assert {:error, changeset} =
               Accounts.register_user(%{@valid_attrs | username: "outronome"})

      assert errors_on(changeset).email != []
    end

    test "returns error with invalid data" do
      assert {:error, changeset} = Accounts.register_user(%{})
      assert errors_on(changeset).username != []
      assert errors_on(changeset).email != []
      assert errors_on(changeset).password != []
    end
  end

  describe "validate_confirmation_token/1" do
    test "confirms email with valid token" do
      insert(:user, confirmed_at: nil, confirmation_token: "valid_token_123")
      assert {:ok, confirmed} = Accounts.validate_confirmation_token("valid_token_123")
      assert confirmed.confirmed_at != nil
      assert confirmed.confirmation_token == nil
    end

    test "returns error with invalid token" do
      assert {:error, :invalid_token} = Accounts.validate_confirmation_token("token_invalido")
    end

    test "returns error with already used token" do
      insert(:user, confirmed_at: nil, confirmation_token: "used_token_456")
      Accounts.validate_confirmation_token("used_token_456")
      assert {:error, :invalid_token} = Accounts.validate_confirmation_token("used_token_456")
    end
  end

  describe "email_confirmed?/1" do
    test "returns true for user with confirmed_at set" do
      user = insert(:user, confirmed_at: DateTime.utc_now())
      assert Accounts.email_confirmed?(user)
    end

    test "returns false for newly registered user (unconfirmed)" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      refute Accounts.email_confirmed?(user)
    end

    test "returns false for user with nil confirmed_at" do
      user = %OGrupoDeEstudos.Accounts.User{confirmed_at: nil}
      refute Accounts.email_confirmed?(user)
    end
  end

  describe "check_credentials/2" do
    setup do
      {:ok, user} =
        Accounts.register_user(%{
          username: "loginuser",
          name: "Login User",
          email: "login@example.com",
          password: "senhasegura123",
          country: "BR",
          state: "SP",
          city: "São Paulo"
        })

      %{user: user}
    end

    test "returns {:ok, user} with correct credentials", %{user: user} do
      assert {:ok, authenticated} = Accounts.check_credentials("loginuser", "senhasegura123")
      assert authenticated.id == user.id
    end

    test "returns error with wrong password" do
      assert {:error, :invalid_credentials} =
               Accounts.check_credentials("loginuser", "senhaerrada")
    end

    test "returns error with nonexistent user" do
      assert {:error, :invalid_credentials} =
               Accounts.check_credentials("naoexiste", "senhasegura123")
    end

    test "returns {:ok, user} with email as identifier", %{user: user} do
      assert {:ok, authenticated} =
               Accounts.check_credentials("login@example.com", "senhasegura123")

      assert authenticated.id == user.id
    end

    test "returns {:ok, user} with mixed-case email input", %{user: user} do
      assert {:ok, authenticated} =
               Accounts.check_credentials("  Login@Example.COM ", "senhasegura123")

      assert authenticated.id == user.id
    end

    test "returns error with wrong password for email identifier" do
      assert {:error, :invalid_credentials} =
               Accounts.check_credentials("login@example.com", "senhaerrada")
    end

    test "returns error with nonexistent email" do
      assert {:error, :invalid_credentials} =
               Accounts.check_credentials("nada@example.com", "senhasegura123")
    end
  end

  describe "login_or_register_google_user/1" do
    @google_profile %{
      google_id: "google-sub-123",
      email: "maria.silva@gmail.com",
      name: "Maria Silva"
    }

    test "registers a new confirmed user with username derived from email" do
      assert {:ok, user, :registered} = Accounts.login_or_register_google_user(@google_profile)

      assert user.username == "mariasilva"
      assert user.email == "maria.silva@gmail.com"
      assert user.google_id == "google-sub-123"
      assert user.confirmed_at != nil
      assert user.password_hash != nil
    end

    test "sends welcome email after google registration, without confirmation link" do
      {:ok, user, :registered} = Accounts.login_or_register_google_user(@google_profile)

      assert_email_sent(fn email ->
        assert {_, address} = hd(email.to)
        assert address == user.email
        refute email.text_body =~ "/confirm/"
        assert email.text_body =~ "Google"
      end)
    end

    test "sends no email on a later login with the same google id" do
      {:ok, _user, :registered} = Accounts.login_or_register_google_user(@google_profile)
      assert_email_sent()

      {:ok, _user, :existing} = Accounts.login_or_register_google_user(@google_profile)

      assert_no_email_sent()
    end

    test "returns the existing user on a later login with the same google id" do
      {:ok, registered, :registered} = Accounts.login_or_register_google_user(@google_profile)

      assert {:ok, user, :existing} = Accounts.login_or_register_google_user(@google_profile)
      assert user.id == registered.id
    end

    test "links google to the existing account with the same email and confirms it" do
      {:ok, existing} = Accounts.register_user(@valid_attrs)
      profile = %{@google_profile | email: existing.email}

      assert {:ok, user, :linked} = Accounts.login_or_register_google_user(profile)

      assert user.id == existing.id
      assert user.google_id == "google-sub-123"
      assert user.confirmed_at != nil
      assert user.username == existing.username
    end

    test "adds a numeric suffix when the derived username is taken" do
      {:ok, _taken} = Accounts.register_user(%{@valid_attrs | username: "mariasilva"})

      assert {:ok, user, :registered} = Accounts.login_or_register_google_user(@google_profile)
      assert user.username == "mariasilva1"
    end

    test "falls back to a default username base when the email prefix is too short" do
      profile = %{@google_profile | email: "ab@gmail.com"}

      assert {:ok, user, :registered} = Accounts.login_or_register_google_user(profile)
      assert String.starts_with?(user.username, "forrozeiro")
    end
  end

  describe "backfill_welcome_emails/1" do
    test "enqueues the welcome email for google-born accounts" do
      {:ok, user, :registered} = Accounts.login_or_register_google_user(@google_profile)
      assert_email_sent()

      cutoff = DateTime.add(DateTime.utc_now(), 60, :second)
      assert {1, [enqueued]} = Accounts.backfill_welcome_emails(cutoff)
      assert enqueued == user.email

      assert_email_sent(fn email ->
        assert {_, address} = hd(email.to)
        assert address == user.email
        refute email.text_body =~ "/confirm/"
        assert email.text_body =~ "Google"
      end)
    end

    test "leaves accounts that linked google later out of it" do
      two_days_ago =
        DateTime.utc_now() |> DateTime.add(-2, :day) |> DateTime.truncate(:second)

      insert(:user,
        google_id: "google-sub-linked",
        inserted_at: DateTime.to_naive(two_days_ago)
      )

      cutoff = DateTime.add(DateTime.utc_now(), 60, :second)
      assert {0, []} = Accounts.backfill_welcome_emails(cutoff)
    end

    test "leaves password accounts out of it" do
      {:ok, _user} = Accounts.register_user(@valid_attrs)
      assert_email_sent()

      cutoff = DateTime.add(DateTime.utc_now(), 60, :second)
      assert {0, []} = Accounts.backfill_welcome_emails(cutoff)
      assert_no_email_sent()
    end

    test "leaves google accounts born after the cutoff out of it" do
      {:ok, _user, :registered} = Accounts.login_or_register_google_user(@google_profile)
      assert_email_sent()

      cutoff = DateTime.add(DateTime.utc_now(), -3600, :second)
      assert {0, []} = Accounts.backfill_welcome_emails(cutoff)
      assert_no_email_sent()
    end
  end

  describe "get_user_by_id/1" do
    test "returns existing user" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      assert Accounts.get_user_by_id(user.id) != nil
    end

    test "returns nil for nonexistent id" do
      assert Accounts.get_user_by_id(Ecto.UUID.generate()) == nil
    end
  end

  describe "admin?/1" do
    test "returns true for admin" do
      assert Accounts.admin?(insert(:admin))
    end

    test "registration cannot self-promote to admin" do
      {:ok, user} = Accounts.register_user(Map.put(@valid_attrs, :role, "admin"))
      refute Accounts.admin?(user)
    end

    test "returns false for regular user" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      refute Accounts.admin?(user)
    end
  end

  describe "search_users/2" do
    test "returns users matching username or name, excluding given user" do
      me = insert(:user, username: "tavano", name: "Tavano L")
      maria = insert(:user, username: "maria_forro", name: "Maria Silva")
      joao = insert(:user, username: "joao123", name: "João Maria")
      _other = insert(:user, username: "carlos", name: "Carlos Souza")

      results = Accounts.search_users("maria", exclude_id: me.id)

      result_ids = Enum.map(results, & &1.id)
      assert maria.id in result_ids
      assert joao.id in result_ids
      refute me.id in result_ids
    end

    test "returns empty list for short queries" do
      _user = insert(:user)
      assert Accounts.search_users("a", exclude_id: Ecto.UUID.generate()) == []
    end

    test "limits results to 5" do
      me = insert(:user)
      for _ <- 1..8, do: insert(:user, name: "Test User")

      results = Accounts.search_users("Test", exclude_id: me.id)
      assert length(results) <= 5
    end

    test "treats LIKE wildcards in the term as literal characters" do
      alice = insert(:user, username: "alice", name: "Alice Silva")

      assert Accounts.search_users("a%") == []
      assert [%{id: id}] = Accounts.search_users("alice")
      assert id == alice.id
    end

    test "works with nil exclude_id (no opts)" do
      user = insert(:user, username: "carlosx", name: "Carlos Souza")
      assert [%{id: id}] = Accounts.search_users("carlosx")
      assert id == user.id
    end
  end

  describe "toggle_dark_mode/1" do
    test "flips dark_mode from false to true" do
      user = insert(:user, dark_mode: false)
      assert {:ok, updated} = Accounts.toggle_dark_mode(user)
      assert updated.dark_mode == true
    end

    test "flips dark_mode from true to false" do
      user = insert(:user, dark_mode: true)
      assert {:ok, updated} = Accounts.toggle_dark_mode(user)
      assert updated.dark_mode == false
    end

    test "persists the new preference to the database" do
      user = insert(:user, dark_mode: false)
      {:ok, _} = Accounts.toggle_dark_mode(user)
      reloaded = Accounts.get_user_by_id(user.id)
      assert reloaded.dark_mode == true
    end
  end

  describe "list_user_summaries/1" do
    test "returns id, username, name and avatar_path for the given ids" do
      user = insert(:user, name: "Maria")
      _other = insert(:user)

      assert [summary] = Accounts.list_user_summaries([user.id])
      assert summary.id == user.id
      assert summary.username == user.username
      assert summary.name == "Maria"
      assert Map.has_key?(summary, :avatar_path)
    end

    test "returns an empty list for an empty list of ids" do
      assert Accounts.list_user_summaries([]) == []
    end
  end

  describe "list_admin_ids/0" do
    test "returns only admin ids" do
      admin = insert(:admin)
      _user = insert(:user)

      assert admin.id in Accounts.list_admin_ids()
      refute _user.id in Accounts.list_admin_ids()
    end
  end

  defp insert_user_with_raw_email(username, raw_email) do
    Repo.insert!(%Accounts.User{
      username: username,
      email: raw_email,
      password_hash: "unused-hash",
      invite_slug: "prof-#{username}"
    })
  end
end
