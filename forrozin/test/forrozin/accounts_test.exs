defmodule Forrozin.AccountsTest do
  use Forrozin.DataCase, async: true

  import Swoosh.TestAssertions

  alias Forrozin.Accounts

  @attrs_validos %{nome_usuario: "novousuario", email: "novo@example.com", senha: "senhasegura"}

  describe "registrar_usuario/1" do
    test "cria usuário com dados válidos e enfileira email de confirmação" do
      assert {:ok, user} = Accounts.registrar_usuario(@attrs_validos)

      assert user.nome_usuario == "novousuario"
      assert user.email == "novo@example.com"
      assert user.papel == "user"
      assert user.senha_hash != nil
      assert user.confirmation_token != nil
      assert user.confirmed_at == nil

      assert_email_sent(
        subject: "Confirme seu email — Forrózin",
        to: [{"novousuario", "novo@example.com"}]
      )
    end

    test "retorna erro com nome_usuario duplicado" do
      Accounts.registrar_usuario(@attrs_validos)

      assert {:error, changeset} =
               Accounts.registrar_usuario(%{@attrs_validos | email: "outro@example.com"})

      assert errors_on(changeset).nome_usuario != []
    end

    test "retorna erro com email duplicado" do
      Accounts.registrar_usuario(@attrs_validos)

      assert {:error, changeset} =
               Accounts.registrar_usuario(%{@attrs_validos | nome_usuario: "outronome"})

      assert errors_on(changeset).email != []
    end

    test "retorna erro com dados inválidos" do
      assert {:error, changeset} = Accounts.registrar_usuario(%{})
      assert errors_on(changeset).nome_usuario != []
      assert errors_on(changeset).email != []
      assert errors_on(changeset).senha != []
    end
  end

  describe "confirmar_email/1" do
    test "confirma o email com token válido" do
      {:ok, user} = Accounts.registrar_usuario(@attrs_validos)
      assert {:ok, confirmado} = Accounts.confirmar_email(user.confirmation_token)
      assert confirmado.confirmed_at != nil
      assert confirmado.confirmation_token == nil
    end

    test "retorna erro com token inválido" do
      assert {:error, :token_invalido} = Accounts.confirmar_email("token_invalido")
    end

    test "retorna erro com token já utilizado" do
      {:ok, user} = Accounts.registrar_usuario(@attrs_validos)
      Accounts.confirmar_email(user.confirmation_token)
      assert {:error, :token_invalido} = Accounts.confirmar_email(user.confirmation_token)
    end
  end

  describe "email_confirmado?/1" do
    test "retorna true para usuário confirmado" do
      {:ok, user} = Accounts.registrar_usuario(@attrs_validos)
      {:ok, confirmado} = Accounts.confirmar_email(user.confirmation_token)
      assert Accounts.email_confirmado?(confirmado)
    end

    test "retorna false para usuário não confirmado" do
      {:ok, user} = Accounts.registrar_usuario(@attrs_validos)
      refute Accounts.email_confirmado?(user)
    end
  end

  describe "autenticar_usuario/2" do
    setup do
      {:ok, user} =
        Accounts.registrar_usuario(%{
          nome_usuario: "loginuser",
          email: "login@example.com",
          senha: "senhasegura123"
        })

      %{user: user}
    end

    test "retorna {:ok, user} com credenciais corretas", %{user: user} do
      assert {:ok, autenticado} = Accounts.autenticar_usuario("loginuser", "senhasegura123")
      assert autenticado.id == user.id
    end

    test "retorna erro com senha errada" do
      assert {:error, :credenciais_invalidas} =
               Accounts.autenticar_usuario("loginuser", "senhaerrada")
    end

    test "retorna erro com usuário inexistente" do
      assert {:error, :credenciais_invalidas} =
               Accounts.autenticar_usuario("naoexiste", "senhasegura123")
    end
  end

  describe "buscar_usuario_por_id/1" do
    test "retorna usuário existente" do
      {:ok, user} = Accounts.registrar_usuario(@attrs_validos)
      assert Accounts.buscar_usuario_por_id(user.id) != nil
    end

    test "retorna nil para id inexistente" do
      assert Accounts.buscar_usuario_por_id(Ecto.UUID.generate()) == nil
    end
  end

  describe "admin?/1" do
    test "retorna true para admin" do
      {:ok, admin} = Accounts.registrar_usuario(Map.put(@attrs_validos, :papel, "admin"))
      assert Accounts.admin?(admin)
    end

    test "retorna false para user comum" do
      {:ok, user} = Accounts.registrar_usuario(@attrs_validos)
      refute Accounts.admin?(user)
    end
  end
end
