defmodule OGrupoDeEstudos.AccountsPasswordResetTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.{Accounts, Metadata}

  describe "request_password_reset/2" do
    test "does not increment counter (only reset_password does)" do
      user = insert(:user, email: "reset@teste.com")

      Accounts.request_password_reset("reset@teste.com", OGrupoDeEstudosWeb.Endpoint)

      count = Metadata.get_integer(Metadata.password_reset_count_name(), "user", user.id)
      assert count == 0
    end

    test "returns :ok even when email does not exist" do
      assert :ok == Accounts.request_password_reset("nope@nowhere.com", OGrupoDeEstudosWeb.Endpoint)
    end

    test "completes without error for existing user" do
      insert(:user, email: "job@teste.com")
      assert :ok == Accounts.request_password_reset("job@teste.com", OGrupoDeEstudosWeb.Endpoint)
    end
  end

  describe "verify_reset_token/2" do
    test "returns user for valid token" do
      user = insert(:user)
      token = Phoenix.Token.sign(OGrupoDeEstudosWeb.Endpoint, "reset_password", user.id)

      assert {:ok, found} = Accounts.verify_reset_token(OGrupoDeEstudosWeb.Endpoint, token)
      assert found.id == user.id
    end

    test "returns error for invalid salt" do
      user = insert(:user)
      token = Phoenix.Token.sign(OGrupoDeEstudosWeb.Endpoint, "wrong_salt", user.id)

      assert {:error, :invalid_token} = Accounts.verify_reset_token(OGrupoDeEstudosWeb.Endpoint, token)
    end

    test "returns error for garbage token" do
      assert {:error, :invalid_token} = Accounts.verify_reset_token(OGrupoDeEstudosWeb.Endpoint, "garbage123")
    end
  end

  describe "reset_password/2" do
    test "updates the password and increments counter" do
      user = insert(:user)

      {:ok, updated} = Accounts.reset_password(user, "novaSenha123")

      assert Argon2.verify_pass("novaSenha123", updated.password_hash)
      assert Metadata.get_integer(Metadata.password_reset_count_name(), "user", user.id) == 1
    end

    test "increments counter on each successful reset" do
      user = insert(:user)

      {:ok, _} = Accounts.reset_password(user, "senha11111")
      {:ok, _} = Accounts.reset_password(user, "senha22222")
      {:ok, _} = Accounts.reset_password(user, "senha33333")

      assert Metadata.get_integer(Metadata.password_reset_count_name(), "user", user.id) == 3
    end

    test "does not increment counter on validation error" do
      user = insert(:user)

      {:error, _} = Accounts.reset_password(user, "short")

      assert Metadata.get_integer(Metadata.password_reset_count_name(), "user", user.id) == 0
    end

    test "rejects password shorter than 8 chars" do
      user = insert(:user)

      {:error, changeset} = Accounts.reset_password(user, "short")

      assert errors_on(changeset).password
    end
  end
end
