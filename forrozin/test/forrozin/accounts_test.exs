defmodule Forrozin.AccountsTest do
  use Forrozin.DataCase, async: true

  import Swoosh.TestAssertions

  alias Forrozin.Accounts

  @valid_attrs %{
    username: "novousuario",
    name: "Novo Usuário",
    email: "novo@example.com",
    password: "senhasegura",
    country: "BR",
    state: "PR",
    city: "Curitiba"
  }

  describe "register_user/1" do
    test "creates user with valid data and auto-confirms" do
      assert {:ok, user} = Accounts.register_user(@valid_attrs)

      assert user.username == "novousuario"
      assert user.email == "novo@example.com"
      assert user.role == "user"
      assert user.password_hash != nil
      assert user.confirmed_at != nil
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
      user = insert(:user, confirmed_at: nil, confirmation_token: "valid_token_123")
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
    test "returns true for auto-confirmed user" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      assert Accounts.email_confirmed?(user)
    end

    test "returns false for user with nil confirmed_at" do
      user = %Forrozin.Accounts.User{confirmed_at: nil}
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
      {:ok, admin} = Accounts.register_user(Map.put(@valid_attrs, :role, "admin"))
      assert Accounts.admin?(admin)
    end

    test "returns false for regular user" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      refute Accounts.admin?(user)
    end
  end
end
