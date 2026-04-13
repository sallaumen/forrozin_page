defmodule Forrozin.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: Forrozin.Repo

  alias Forrozin.Accounts.User
  alias Forrozin.Enciclopedia.{Categoria, ConceitoTecnico, Conexao, Passo, Secao, Subsecao}

  def user_factory do
    %User{
      nome_usuario: sequence(:nome_usuario, &"usuario#{&1}"),
      email: sequence(:email, &"usuario#{&1}@example.com"),
      senha_hash: Argon2.hash_pwd_salt("senhateste123"),
      papel: "user",
      confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }
  end

  def admin_factory do
    %User{
      nome_usuario: sequence(:nome_usuario, &"admin#{&1}"),
      email: sequence(:email, &"admin#{&1}@example.com"),
      senha_hash: Argon2.hash_pwd_salt("senhateste123"),
      papel: "admin",
      confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }
  end

  def categoria_factory do
    %Categoria{
      nome: sequence(:nome_categoria, &"categoria_#{&1}"),
      rotulo: sequence(:rotulo_categoria, &"Categoria #{&1}"),
      cor: "#c0392b"
    }
  end

  def secao_factory do
    %Secao{
      titulo: sequence(:titulo_secao, &"Seção #{&1}"),
      posicao: sequence(:posicao_secao, & &1),
      categoria: build(:categoria)
    }
  end

  def subsecao_factory do
    %Subsecao{
      titulo: sequence(:titulo_subsecao, &"Subseção #{&1}"),
      posicao: sequence(:posicao_subsecao, & &1),
      secao: build(:secao)
    }
  end

  def passo_factory do
    %Passo{
      codigo: sequence(:codigo_passo, &"P#{&1}"),
      nome: sequence(:nome_passo, &"Passo #{&1}"),
      posicao: sequence(:posicao_passo, & &1),
      secao: build(:secao),
      categoria: build(:categoria)
    }
  end

  def conexao_factory do
    %Conexao{
      tipo: "saida",
      passo_origem: build(:passo),
      passo_destino: build(:passo)
    }
  end

  def conceito_tecnico_factory do
    %ConceitoTecnico{
      titulo: sequence(:titulo_conceito, &"Conceito #{&1}"),
      descricao: "Descrição técnica do conceito."
    }
  end
end
