defmodule Forrozin.Accounts.User do
  @moduledoc """
  Schema de usuário da plataforma.

  O papel (`papel`) define o nível de acesso:
  - `"user"` — acesso à enciclopédia (padrão)
  - `"admin"` — acesso à enciclopédia + conteúdo wip + painel admin

  Promoção a admin é feita diretamente no banco — sem interface.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @papeis_validos ~w(user admin)
  @min_senha 8

  schema "usuarios" do
    field :nome_usuario, :string
    field :email, :string
    field :senha, :string, virtual: true
    field :senha_hash, :string
    field :papel, :string, default: "user"
    field :confirmation_token, :string
    field :confirmed_at, :naive_datetime

    timestamps()
  end

  @doc "Changeset para registro de novo usuário."
  def changeset_registro(user, attrs) do
    user
    |> cast(attrs, [:nome_usuario, :email, :senha, :papel, :confirmation_token])
    |> validate_required([:nome_usuario, :email, :senha])
    |> validate_length(:nome_usuario, min: 3, max: 30)
    |> validate_format(:nome_usuario, ~r/^[a-z0-9_]+$/,
      message: "use apenas letras minúsculas, números e _"
    )
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "formato inválido")
    |> validate_length(:senha, min: @min_senha)
    |> validate_inclusion(:papel, @papeis_validos)
    |> unique_constraint(:nome_usuario, message: "nome de usuário já existe")
    |> unique_constraint(:email, message: "email já cadastrado")
    |> hash_senha()
  end

  @doc "Changeset que marca o email como confirmado e invalida o token."
  def changeset_confirmacao(user) do
    change(user,
      confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      confirmation_token: nil
    )
  end

  defp hash_senha(changeset) do
    case get_change(changeset, :senha) do
      nil -> changeset
      senha -> put_change(changeset, :senha_hash, Argon2.hash_pwd_salt(senha))
    end
  end
end
