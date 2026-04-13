defmodule Forrozin.Admin do
  @moduledoc """
  Contexto de ação administrativa.

  Responsável por operações que modificam o estado da enciclopédia —
  operações com efeitos colaterais restritas a usuários com papel `admin`.

  A autorização é responsabilidade da camada Web (LiveViews/Plugs).
  Este módulo executa as operações sem verificar permissões diretamente.
  """

  alias Forrozin.Enciclopedia.Conexao
  alias Forrozin.Repo

  @doc """
  Cria uma conexão direcional entre dois passos.

  Retorna `{:ok, conexao}` ou `{:error, changeset}` em caso de
  dados inválidos ou violação de constraint de unicidade.
  """
  def criar_conexao(attrs) do
    %Conexao{}
    |> Conexao.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Atualiza o rótulo ou descrição de uma conexão existente.

  Retorna `{:ok, conexao}` ou `{:error, :nao_encontrado}` se o ID não existir.
  """
  def editar_conexao(id, attrs) do
    case Repo.get(Conexao, id) do
      nil -> {:error, :nao_encontrado}
      conexao -> conexao |> Conexao.changeset(attrs) |> Repo.update()
    end
  end

  @doc """
  Remove uma conexão pelo ID.

  Retorna `{:ok, conexao}` se removida com sucesso,
  ou `{:error, :nao_encontrado}` se o ID não existir.
  """
  def remover_conexao(id) do
    case Repo.get(Conexao, id) do
      nil -> {:error, :nao_encontrado}
      conexao -> Repo.delete(conexao)
    end
  end
end
