defmodule Forrozin.AccountsTest do
  use Forrozin.DataCase, async: true

  import Swoosh.TestAssertions

  alias Forrozin.Accounts

  @attrs_validos %{username: "novousuario", email: "novo@example.com", password: "senhasegura"}

  describe "register_user/1" do
    test "cria usuário com dados válidos e enfileira email de confirmação" do
      assert {:ok, user} = Accounts.register_user(@attrs_validos)

      assert user.username == "novousuario"
      assert user.email == "novo@example.com"
      assert user.role == "user"
      assert user.password_hash != nil
      assert user.confirmation_token != nil
      assert user.confirmed_at == nil

      assert_email_sent(
        subject: "Confirme seu email — Forrózin",
        to: [{"novousuario", "novo@example.com"}]
      )
    end

    test "retorna erro com username duplicado" do
      Accounts.register_user(@attrs_validos)

      assert {:error, changeset} =
               Accounts.register_user(%{@attrs_validos | email: "outro@example.com"})

      assert errors_on(changeset).username != []
    end

    test "retorna erro com email duplicado" do
      Accounts.register_user(@attrs_validos)

      assert {:error, changeset} =
               Accounts.register_user(%{@attrs_validos | username: "outronome"})

      assert errors_on(changeset).email != []
    end

    test "retorna erro com dados inválidos" do
      assert {:error, changeset} = Accounts.register_user(%{})
      assert errors_on(changeset).username != []
      assert errors_on(changeset).email != []
      assert errors_on(changeset).password != []
    end
  end

  describe "confirm_email/1" do
    test "confirma o email com token válido" do
      {:ok, user} = Accounts.register_user(@attrs_validos)
      assert {:ok, confirmed} = Accounts.confirm_email(user.confirmation_token)
      assert confirmed.confirmed_at != nil
      assert confirmed.confirmation_token == nil
    end

    test "retorna erro com token inválido" do
      assert {:error, :invalid_token} = Accounts.confirm_email("token_invalido")
    end

    test "retorna erro com token já utilizado" do
      {:ok, user} = Accounts.register_user(@attrs_validos)
      Accounts.confirm_email(user.confirmation_token)
      assert {:error, :invalid_token} = Accounts.confirm_email(user.confirmation_token)
    end
  end

  describe "email_confirmed?/1" do
    test "retorna true para usuário confirmado" do
      {:ok, user} = Accounts.register_user(@attrs_validos)
      {:ok, confirmed} = Accounts.confirm_email(user.confirmation_token)
      assert Accounts.email_confirmed?(confirmed)
    end

    test "retorna false para usuário não confirmado" do
      {:ok, user} = Accounts.register_user(@attrs_validos)
      refute Accounts.email_confirmed?(user)
    end
  end

  describe "authenticate_user/2" do
    setup do
      {:ok, user} =
        Accounts.register_user(%{
          username: "loginuser",
          email: "login@example.com",
          password: "senhasegura123"
        })

      %{user: user}
    end

    test "retorna {:ok, user} com credenciais corretas", %{user: user} do
      assert {:ok, authenticated} = Accounts.authenticate_user("loginuser", "senhasegura123")
      assert authenticated.id == user.id
    end

    test "retorna erro com senha errada" do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user("loginuser", "senhaerrada")
    end

    test "retorna erro com usuário inexistente" do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_user("naoexiste", "senhasegura123")
    end
  end

  describe "get_user_by_id/1" do
    test "retorna usuário existente" do
      {:ok, user} = Accounts.register_user(@attrs_validos)
      assert Accounts.get_user_by_id(user.id) != nil
    end

    test "retorna nil para id inexistente" do
      assert Accounts.get_user_by_id(Ecto.UUID.generate()) == nil
    end
  end

  describe "admin?/1" do
    test "retorna true para admin" do
      {:ok, admin} = Accounts.register_user(Map.put(@attrs_validos, :role, "admin"))
      assert Accounts.admin?(admin)
    end

    test "retorna false para user comum" do
      {:ok, user} = Accounts.register_user(@attrs_validos)
      refute Accounts.admin?(user)
    end
  end
end
