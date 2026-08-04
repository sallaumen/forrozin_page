defmodule OGrupoDeEstudos.Accounts.UserTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Accounts.User

  @valid_attrs %{
    username: "tata",
    name: "Tatá Tavano",
    email: "tata@example.com",
    password: "senhasegura",
    country: "BR",
    state: "PR",
    city: "Curitiba"
  }

  describe "registration_changeset/2" do
    test "valid with correct data" do
      changeset = User.registration_changeset(%User{}, @valid_attrs)
      assert changeset.valid?
      assert get_change(changeset, :password_hash) != nil
    end

    test "generates confirmation_token when email is present" do
      changeset = User.registration_changeset(%User{}, @valid_attrs)
      token = get_change(changeset, :confirmation_token)
      assert is_binary(token)
      assert String.length(token) > 20
    end

    test "invalid without username" do
      attrs = Map.delete(@valid_attrs, :username)
      changeset = User.registration_changeset(%User{}, attrs)
      assert "can't be blank" in errors_on(changeset).username
    end

    test "invalid without email" do
      attrs = Map.delete(@valid_attrs, :email)
      changeset = User.registration_changeset(%User{}, attrs)
      assert "can't be blank" in errors_on(changeset).email
    end

    test "invalid with malformed email" do
      changeset = User.registration_changeset(%User{}, %{@valid_attrs | email: "naoemail"})
      assert errors_on(changeset).email != []
    end

    test "downcases and trims email" do
      changeset =
        User.registration_changeset(%User{}, %{@valid_attrs | email: "  Tata@Example.COM  "})

      assert changeset.valid?
      assert get_change(changeset, :email) == "tata@example.com"
    end

    test "invalid without password" do
      attrs = Map.delete(@valid_attrs, :password)
      changeset = User.registration_changeset(%User{}, attrs)
      assert "can't be blank" in errors_on(changeset).password
    end

    test "invalid with username too short" do
      changeset = User.registration_changeset(%User{}, %{@valid_attrs | username: "ab"})
      assert errors_on(changeset).username != []
    end

    test "invalid with username too long" do
      changeset =
        User.registration_changeset(%User{}, %{
          @valid_attrs
          | username: String.duplicate("a", 31)
        })

      assert errors_on(changeset).username != []
    end

    test "invalid with disallowed characters in username" do
      changeset = User.registration_changeset(%User{}, %{@valid_attrs | username: "Tata!"})
      assert errors_on(changeset).username != []
    end

    test "invalid with password too short" do
      changeset = User.registration_changeset(%User{}, %{@valid_attrs | password: "curta"})
      assert errors_on(changeset).password != []
    end

    test "default role is user" do
      changeset = User.registration_changeset(%User{}, @valid_attrs)
      assert get_field(changeset, :role) == :user
    end

    test "ignores role sent in registration params (no self-promotion)" do
      changeset = User.registration_changeset(%User{}, Map.put(@valid_attrs, :role, "admin"))
      assert get_field(changeset, :role) == :user
    end

    test "ignores confirmation_token sent in registration params" do
      changeset =
        User.registration_changeset(
          %User{},
          Map.put(@valid_attrs, :confirmation_token, "forjado")
        )

      assert get_field(changeset, :confirmation_token) != "forjado"
    end

    test "accepts is_teacher flag" do
      changeset = User.registration_changeset(%User{}, Map.put(@valid_attrs, :is_teacher, true))

      assert changeset.valid?
      assert get_field(changeset, :is_teacher)
    end
  end

  describe "google_registration_changeset/2" do
    @google_attrs %{
      username: "tata",
      email: "tata@gmail.com",
      name: "Tatá Tavano",
      google_id: "google-sub-123"
    }

    test "valid with google profile data and generates a password hash" do
      changeset = User.google_registration_changeset(%User{}, @google_attrs)

      assert changeset.valid?
      assert get_change(changeset, :password_hash) != nil
    end

    test "marks the email as confirmed without a confirmation token" do
      changeset = User.google_registration_changeset(%User{}, @google_attrs)

      assert get_change(changeset, :confirmed_at) != nil
      assert get_change(changeset, :confirmation_token) == nil
    end

    test "downcases and trims email" do
      changeset =
        User.google_registration_changeset(%User{}, %{@google_attrs | email: " Tata@Gmail.COM "})

      assert get_change(changeset, :email) == "tata@gmail.com"
    end

    test "invalid without google_id" do
      attrs = Map.delete(@google_attrs, :google_id)
      changeset = User.google_registration_changeset(%User{}, attrs)

      assert "can't be blank" in errors_on(changeset).google_id
    end

    test "valid without city, state or two-word name" do
      changeset =
        User.google_registration_changeset(%User{}, %{@google_attrs | name: "Tatá"})

      assert changeset.valid?
    end

    test "generates invite slug from username" do
      changeset = User.google_registration_changeset(%User{}, @google_attrs)

      assert get_change(changeset, :invite_slug) == "prof-tata"
    end
  end

  describe "link_google_changeset/2" do
    test "sets google_id and confirms an unconfirmed user" do
      user = %User{google_id: nil, confirmed_at: nil}
      changeset = User.link_google_changeset(user, "google-sub-123")

      assert get_change(changeset, :google_id) == "google-sub-123"
      assert get_change(changeset, :confirmed_at) != nil
    end

    test "keeps the original confirmed_at when already confirmed" do
      confirmed_at = ~U[2026-01-01 12:00:00Z]
      user = %User{google_id: nil, confirmed_at: confirmed_at}
      changeset = User.link_google_changeset(user, "google-sub-123")

      assert get_field(changeset, :confirmed_at) == confirmed_at
    end
  end

  describe "profile_complete?/1" do
    test "returns true when brazilian user has city and state" do
      assert User.profile_complete?(%User{country: "BR", state: "PR", city: "Curitiba"})
    end

    test "returns false when city is missing" do
      refute User.profile_complete?(%User{country: "BR", state: "PR", city: nil})
    end

    test "returns false when state is missing for a brazilian user" do
      refute User.profile_complete?(%User{country: "BR", state: nil, city: "Curitiba"})
    end

    test "returns true for a foreign user without state" do
      assert User.profile_complete?(%User{country: "AR", state: nil, city: "Buenos Aires"})
    end
  end

  describe "profile_changeset/2" do
    test "allows toggling is_teacher from profile settings" do
      user = %User{
        name: "Tatá Tavano",
        username: "tata",
        country: "BR",
        state: "PR",
        city: "Curitiba"
      }

      changeset =
        User.profile_changeset(user, %{
          name: "Tatá Tavano",
          username: "tata",
          country: "BR",
          state: "PR",
          city: "Curitiba",
          is_teacher: true
        })

      assert changeset.valid?
      assert get_field(changeset, :is_teacher)
    end
  end

  describe "profile_changeset/2 dark_mode" do
    test "accepts dark_mode true" do
      user = %User{
        name: "Tatá Tavano",
        username: "tata",
        country: "BR",
        state: "PR",
        city: "Curitiba"
      }

      changeset =
        User.profile_changeset(user, %{
          name: "Tatá Tavano",
          username: "tata",
          country: "BR",
          state: "PR",
          city: "Curitiba",
          dark_mode: true
        })

      assert changeset.valid?
      assert get_field(changeset, :dark_mode) == true
    end

    test "accepts dark_mode false" do
      user = %User{
        name: "Tatá Tavano",
        username: "tata",
        country: "BR",
        state: "PR",
        city: "Curitiba",
        dark_mode: true
      }

      changeset =
        User.profile_changeset(user, %{
          name: "Tatá Tavano",
          username: "tata",
          country: "BR",
          state: "PR",
          city: "Curitiba",
          dark_mode: false
        })

      assert changeset.valid?
      assert get_field(changeset, :dark_mode) == false
    end

    test "defaults dark_mode to false on new user" do
      changeset = User.registration_changeset(%User{}, @valid_attrs)
      assert get_field(changeset, :dark_mode) == false
    end
  end

  describe "confirmation_changeset/1" do
    test "sets confirmed_at and clears the token" do
      user = %User{confirmation_token: "algum_token", confirmed_at: nil}
      changeset = User.confirmation_changeset(user)
      assert get_change(changeset, :confirmed_at) != nil
      assert get_change(changeset, :confirmation_token) == nil
    end
  end

  describe "Inspect redaction" do
    test "does not leak sensitive fields when inspected" do
      user = %User{
        password: "senha_em_claro",
        password_hash: "hash_secreto",
        confirmation_token: "token_secreto"
      }

      inspected = inspect(user)

      refute inspected =~ "senha_em_claro"
      refute inspected =~ "hash_secreto"
      refute inspected =~ "token_secreto"
    end

    test "still shows non-sensitive fields when inspected" do
      user = %User{username: "tata", email: "tata@example.com"}
      inspected = inspect(user)

      assert inspected =~ "tata"
      assert inspected =~ "tata@example.com"
    end
  end
end
