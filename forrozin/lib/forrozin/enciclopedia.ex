defmodule Forrozin.Enciclopedia do
  @moduledoc """
  Contexto de leitura da enciclopédia de forró roots.

  Módulo de cálculo puro: todas as funções são consultas ao banco sem
  efeitos colaterais. A visibilidade dos passos é controlada aqui —
  passos `wip: true` ou `status: "rascunho"` não aparecem para o público.
  """

  import Ecto.Query

  alias Forrozin.Enciclopedia.{Categoria, ConceitoTecnico, Conexao, Passo, Secao}
  alias Forrozin.Repo

  # ---------------------------------------------------------------------------
  # Categorias
  # ---------------------------------------------------------------------------

  @doc "Lista todas as categorias ordenadas por rótulo."
  def listar_categorias do
    Categoria
    |> order_by([c], asc: c.rotulo)
    |> Repo.all()
  end

  @doc "Busca uma categoria pelo nome interno (ex: 'sacadas', 'bases')."
  def buscar_categoria_por_nome(nome) do
    case Repo.get_by(Categoria, nome: nome) do
      nil -> {:error, :nao_encontrado}
      categoria -> {:ok, categoria}
    end
  end

  # ---------------------------------------------------------------------------
  # Seções
  # ---------------------------------------------------------------------------

  @doc "Lista todas as seções ordenadas por posição."
  def listar_secoes do
    Secao
    |> order_by([s], asc: s.posicao)
    |> Repo.all()
  end

  @doc """
  Lista seções com passos e subseções pré-carregados.

  Opções:
  - `admin: true` — inclui passos `wip` (para administradores).

  Por padrão omite passos `wip` e `rascunho` (visibilidade pública).
  """
  def listar_secoes_com_passos(opts \\ []) do
    admin = Keyword.get(opts, :admin, false)

    passos_visiveis =
      from(p in Passo,
        where:
          ^if(admin,
            do: dynamic([p], p.status == "publicado"),
            else: dynamic([p], p.wip == false and p.status == "publicado")
          ),
        order_by: [asc: p.posicao]
      )

    Secao
    |> order_by([s], asc: s.posicao)
    |> Repo.all()
    |> Repo.preload([
      :categoria,
      passos: passos_visiveis,
      subsecoes: [passos: passos_visiveis]
    ])
  end

  # ---------------------------------------------------------------------------
  # Passos
  # ---------------------------------------------------------------------------

  @doc "Conta o total de passos publicados e não-wip (visível ao público)."
  def contar_passos_publicos do
    Passo
    |> where([p], p.wip == false and p.status == "publicado")
    |> Repo.aggregate(:count)
  end

  @doc """
  Busca um passo pelo código único (ex: "BF", "GP-D").

  Respeita a política de visibilidade: passos wip ou rascunho retornam
  `{:error, :nao_encontrado}` para o público.
  """
  def buscar_passo_por_codigo(codigo) do
    query =
      from(p in Passo,
        where: p.codigo == ^codigo and p.wip == false and p.status == "publicado"
      )

    case Repo.one(query) do
      nil -> {:error, :nao_encontrado}
      passo -> {:ok, passo}
    end
  end

  @doc """
  Busca um passo com todos os detalhes: categoria, conceitos técnicos e conexões.

  Opções:
  - `admin: true` — inclui passos `wip`.
  """
  def buscar_passo_com_detalhes(codigo, opts \\ []) do
    admin = Keyword.get(opts, :admin, false)

    query =
      if admin do
        from(p in Passo, where: p.codigo == ^codigo and p.status == "publicado")
      else
        from(p in Passo,
          where: p.codigo == ^codigo and p.wip == false and p.status == "publicado"
        )
      end

    case Repo.one(query) do
      nil ->
        {:error, :nao_encontrado}

      passo ->
        passo =
          Repo.preload(passo, [
            :categoria,
            :conceitos_tecnicos,
            conexoes_como_origem: :passo_destino,
            conexoes_como_destino: :passo_origem
          ])

        {:ok, passo}
    end
  end

  @doc """
  Busca passos pelo nome (case-insensitive, correspondência parcial).

  Opções:
  - `admin: true` — inclui passos `wip` na busca.

  Por padrão retorna apenas passos públicos.
  """
  def buscar_passos(termo, opts \\ []) do
    admin = Keyword.get(opts, :admin, false)
    termo_lower = String.downcase(termo)

    base_query =
      from(p in Passo,
        where:
          p.status == "publicado" and fragment("lower(?)", p.nome) |> like(^"%#{termo_lower}%"),
        order_by: [asc: p.nome]
      )

    query = if admin, do: base_query, else: where(base_query, [p], p.wip == false)

    Repo.all(query)
  end

  # ---------------------------------------------------------------------------
  # Grafo
  # ---------------------------------------------------------------------------

  @doc """
  Retorna o grafo de conexões entre passos.

  O retorno é um mapa com:
  - `:nos` — lista de passos visíveis, com `:categoria` precarregada, ordenados por nome.
  - `:arestas` — lista de conexões entre passos visíveis, com `:passo_origem` e
    `:passo_destino` precarregados.

  Opções:
  - `admin: true` — inclui passos `wip` nos nós e nas arestas.
  """
  def listar_grafo(opts \\ []) do
    admin = Keyword.get(opts, :admin, false)

    nos =
      from(p in Passo,
        where:
          ^if(admin,
            do: dynamic([p], p.status == "publicado"),
            else: dynamic([p], p.wip == false and p.status == "publicado")
          ),
        order_by: [asc: p.nome],
        preload: [:categoria]
      )
      |> Repo.all()

    passo_ids = Enum.map(nos, & &1.id)

    arestas =
      from(c in Conexao,
        where: c.passo_origem_id in ^passo_ids and c.passo_destino_id in ^passo_ids,
        preload: [:passo_origem, :passo_destino]
      )
      |> Repo.all()

    %{nos: nos, arestas: arestas}
  end

  @doc """
  Retorna todos os passos (incluindo wip) indexados por código.

  Uso interno: Mix tasks de seed e extração de conexões.
  Retorna `%{codigo => passo}`.
  """
  def listar_todos_passos_mapa do
    Passo
    |> Repo.all()
    |> Map.new(&{&1.codigo, &1})
  end

  # ---------------------------------------------------------------------------
  # Conceitos Técnicos
  # ---------------------------------------------------------------------------

  @doc "Lista todos os conceitos técnicos de condução ordenados por título."
  def listar_conceitos_tecnicos do
    ConceitoTecnico
    |> order_by([c], asc: c.titulo)
    |> Repo.all()
  end
end
