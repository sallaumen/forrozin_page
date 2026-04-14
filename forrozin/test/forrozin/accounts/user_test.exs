defmodule Forrozin.Accounts.UserTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Accounts.User

  @attrs_validos %{username: "tata", email: "tata@example.com", password: "senhasegura"}

  describe "registration_changeset/2" do
    test "válido com dados corretos" do
      changeset = User.registration_changeset(%User{}, @attrs_validos)
      assert changeset.valid?
      assert get_change(changeset, :password_hash) != nil
    end

    test "inválido sem username" do
      attrs = Map.delete(@attrs_validos, :username)
      changeset = User.registration_changeset(%User{}, attrs)
      assert "can't be blank" in errors_on(changeset).username
    end

    test "inválido sem email" do
      attrs = Map.delete(@attrs_validos, :email)
      changeset = User.registration_changeset(%User{}, attrs)
      assert "can't be blank" in errors_on(changeset).email
    end

    test "inválido com email em formato incorreto" do
      changeset = User.registration_changeset(%User{}, %{@attrs_validos | email: "naoemail"})
      assert errors_on(changeset).email != []
    end

    test "inválido sem senha" do
      attrs = Map.delete(@attrs_validos, :password)
      changeset = User.registration_changeset(%User{}, attrs)
      assert "can't be blank" in errors_on(changeset).password
    end

    test "inválido com username muito curto" do
      changeset = User.registration_changeset(%User{}, %{@attrs_validos | username: "ab"})
      assert errors_on(changeset).username != []
    end

    test "inválido com username muito longo" do
      changeset =
        User.registration_changeset(%User{}, %{
          @attrs_validos
          | username: String.duplicate("a", 31)
        })

      assert errors_on(changeset).username != []
    end

    test "inválido com caracteres não permitidos no username" do
      changeset = User.registration_changeset(%User{}, %{@attrs_validos | username: "Tata!"})
      assert errors_on(changeset).username != []
    end

    test "inválido com senha muito curta" do
      changeset = User.registration_changeset(%User{}, %{@attrs_validos | password: "curta"})
      assert errors_on(changeset).password != []
    end

    test "role padrão é user" do
      changeset = User.registration_changeset(%User{}, @attrs_validos)
      assert get_field(changeset, :role) == "user"
    end

    test "aceita role admin" do
      changeset = User.registration_changeset(%User{}, Map.put(@attrs_validos, :role, "admin"))
      assert changeset.valid?
    end

    test "rejeita role inválido" do
      changeset = User.registration_changeset(%User{}, Map.put(@attrs_validos, :role, "superadmin"))
      assert errors_on(changeset).role != []
    end
  end

  describe "confirmation_changeset/1" do
    test "define confirmed_at e limpa o token" do
      user = %User{confirmation_token: "algum_token", confirmed_at: nil}
      changeset = User.confirmation_changeset(user)
      assert get_change(changeset, :confirmed_at) != nil
      assert get_change(changeset, :confirmation_token) == nil
    end
  end
end
