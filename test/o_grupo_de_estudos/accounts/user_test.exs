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
      assert get_field(changeset, :role) == "user"
    end

    test "accepts admin role" do
      changeset = User.registration_changeset(%User{}, Map.put(@valid_attrs, :role, "admin"))
      assert changeset.valid?
    end

    test "rejects invalid role" do
      changeset = User.registration_changeset(%User{}, Map.put(@valid_attrs, :role, "superadmin"))
      assert errors_on(changeset).role != []
    end

    test "accepts is_teacher flag" do
      changeset = User.registration_changeset(%User{}, Map.put(@valid_attrs, :is_teacher, true))

      assert changeset.valid?
      assert get_field(changeset, :is_teacher)
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

  describe "profile_changeset/2 — dark_mode" do
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
end
