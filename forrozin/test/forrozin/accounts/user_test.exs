defmodule Forrozin.Accounts.UserTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Accounts.User

  @attrs_validos %{nome_usuario: "tata", email: "tata@example.com", senha: "senhasegura"}

  describe "changeset_registro/2" do
    test "válido com dados corretos" do
      changeset = User.changeset_registro(%User{}, @attrs_validos)
      assert changeset.valid?
      assert get_change(changeset, :senha_hash) != nil
    end

    test "inválido sem nome_usuario" do
      attrs = Map.delete(@attrs_validos, :nome_usuario)
      changeset = User.changeset_registro(%User{}, attrs)
      assert "can't be blank" in errors_on(changeset).nome_usuario
    end

    test "inválido sem email" do
      attrs = Map.delete(@attrs_validos, :email)
      changeset = User.changeset_registro(%User{}, attrs)
      assert "can't be blank" in errors_on(changeset).email
    end

    test "inválido com email em formato incorreto" do
      changeset = User.changeset_registro(%User{}, %{@attrs_validos | email: "naoemail"})
      assert errors_on(changeset).email != []
    end

    test "inválido sem senha" do
      attrs = Map.delete(@attrs_validos, :senha)
      changeset = User.changeset_registro(%User{}, attrs)
      assert "can't be blank" in errors_on(changeset).senha
    end

    test "inválido com nome_usuario muito curto" do
      changeset = User.changeset_registro(%User{}, %{@attrs_validos | nome_usuario: "ab"})
      assert errors_on(changeset).nome_usuario != []
    end

    test "inválido com nome_usuario muito longo" do
      changeset =
        User.changeset_registro(%User{}, %{
          @attrs_validos
          | nome_usuario: String.duplicate("a", 31)
        })

      assert errors_on(changeset).nome_usuario != []
    end

    test "inválido com caracteres não permitidos no nome_usuario" do
      changeset = User.changeset_registro(%User{}, %{@attrs_validos | nome_usuario: "Tata!"})
      assert errors_on(changeset).nome_usuario != []
    end

    test "inválido com senha muito curta" do
      changeset = User.changeset_registro(%User{}, %{@attrs_validos | senha: "curta"})
      assert errors_on(changeset).senha != []
    end

    test "papel padrão é user" do
      changeset = User.changeset_registro(%User{}, @attrs_validos)
      assert get_field(changeset, :papel) == "user"
    end

    test "aceita papel admin" do
      changeset = User.changeset_registro(%User{}, Map.put(@attrs_validos, :papel, "admin"))
      assert changeset.valid?
    end

    test "rejeita papel inválido" do
      changeset = User.changeset_registro(%User{}, Map.put(@attrs_validos, :papel, "superadmin"))
      assert errors_on(changeset).papel != []
    end
  end

  describe "changeset_confirmacao/1" do
    test "define confirmed_at e limpa o token" do
      user = %User{confirmation_token: "algum_token", confirmed_at: nil}
      changeset = User.changeset_confirmacao(user)
      assert get_change(changeset, :confirmed_at) != nil
      assert get_change(changeset, :confirmation_token) == nil
    end
  end
end
