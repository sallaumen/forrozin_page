defmodule ForrozinWeb.GrafoVisualLive do
  use ForrozinWeb, :live_view

  alias Forrozin.{Accounts, Enciclopedia}

  on_mount {ForrozinWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    grafo = Enciclopedia.listar_grafo()
    graph_json = montar_json(grafo)

    nos_conectados =
      grafo.arestas
      |> Enum.flat_map(&[&1.passo_origem_id, &1.passo_destino_id])
      |> MapSet.new()
      |> MapSet.size()

    {:ok,
     socket
     |> assign(:page_title, "Mapa de Passos")
     |> assign(:graph_json, graph_json)
     |> assign(:n_nos, nos_conectados)
     |> assign(:n_arestas, length(grafo.arestas))
     |> assign(:is_admin, Accounts.admin?(socket.assigns.current_user))}
  end

  # ---------------------------------------------------------------------------
  # Privado
  # ---------------------------------------------------------------------------

  defp montar_json(%{nos: nos, arestas: arestas}) do
    # Só exibe nós que participam de pelo menos uma conexão
    codigos_conectados =
      arestas
      |> Enum.flat_map(fn c -> [c.passo_origem.codigo, c.passo_destino.codigo] end)
      |> MapSet.new()

    nos_conectados = Enum.filter(nos, &MapSet.member?(codigos_conectados, &1.codigo))

    Jason.encode!(%{
      nodes:
        Enum.map(nos_conectados, fn p ->
          %{
            id: p.codigo,
            nome: p.nome,
            categoria: p.categoria.rotulo,
            cor: p.categoria.cor
          }
        end),
      edges:
        Enum.map(arestas, fn c ->
          %{from: c.passo_origem.codigo, to: c.passo_destino.codigo, label: c.rotulo}
        end)
    })
  end
end
