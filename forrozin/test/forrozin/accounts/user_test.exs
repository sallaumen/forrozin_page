defmodule Forrozin.Accounts.UserTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Accounts.User

  @valid_attrs %{username: "tata", email: "tata@example.com", password: "senhasegura", state: "PR", city: "Curitiba"}

  describe "registration_changeset/2" do
    test "valid with correct data" do
      changeset = User.registration_changeset(%User{}, @valid_attrs)
      assert changeset.valid?
      assert get_change(changeset, :password_hash) != nil
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
