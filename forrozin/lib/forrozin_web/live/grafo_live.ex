defmodule ForrozinWeb.GrafoLive do
  use ForrozinWeb, :live_view

  alias Forrozin.{Accounts, Admin, Admin.Backup, Enciclopedia}

  on_mount {ForrozinWeb.UserAuth, :ensure_admin}

  @impl true
  def mount(_params, _session, socket) do
    grafo = Enciclopedia.listar_grafo()

    {:ok,
     socket
     |> assign(:is_admin, Accounts.admin?(socket.assigns.current_user))
     |> assign(:modo_edicao, false)
     |> assign(:origens, MapSet.new())
     |> assign(:destinos, MapSet.new())
     |> assign(:ultimo_backup, nil)
     |> assign(:rotulo_conexao, "")
     |> assign(:page_title, "Grafo de Passos")
     |> carregar_grafo(grafo)}
  end

  @impl true
  def handle_event("toggle_modo_edicao", _params, socket) do
    if socket.assigns.is_admin do
      {:noreply,
       socket
       |> update(:modo_edicao, &(!&1))
       |> assign(:origens, MapSet.new())
       |> assign(:destinos, MapSet.new())}
    else
      {:noreply, socket}
    end
  end

  def handle_event("selecionar_origem", %{"passo_id" => id}, socket) do
    if socket.assigns.is_admin do
      {:noreply, update(socket, :origens, &toggle_selecao(&1, id))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("selecionar_destino", %{"passo_id" => id}, socket) do
    if socket.assigns.is_admin do
      {:noreply, update(socket, :destinos, &toggle_selecao(&1, id))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("atualizar_rotulo", %{"rotulo" => rotulo}, socket) do
    {:noreply, assign(socket, :rotulo_conexao, rotulo)}
  end

  def handle_event("criar_conexoes", _params, socket) do
    if socket.assigns.is_admin do
      origens = MapSet.to_list(socket.assigns.origens)
      destinos = MapSet.to_list(socket.assigns.destinos)
      rotulo = nilify(socket.assigns.rotulo_conexao)

      for origem_id <- origens, destino_id <- destinos do
        Admin.criar_conexao(%{
          passo_origem_id: origem_id,
          passo_destino_id: destino_id,
          tipo: "saida",
          rotulo: rotulo
        })
      end

      grafo = Enciclopedia.listar_grafo()

      {:noreply,
       socket
       |> assign(:origens, MapSet.new())
       |> assign(:destinos, MapSet.new())
       |> assign(:rotulo_conexao, "")
       |> carregar_grafo(grafo)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("editar_rotulo_conexao", %{"conexao_id" => id, "rotulo" => rotulo}, socket) do
    if socket.assigns.is_admin do
      Admin.editar_conexao(id, %{rotulo: nilify(rotulo)})
      grafo = Enciclopedia.listar_grafo()
      {:noreply, carregar_grafo(socket, grafo)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("criar_backup", _params, socket) do
    if socket.assigns.is_admin do
      caminho = Backup.criar_backup!()
      nome = Path.basename(caminho)
      {:noreply, assign(socket, :ultimo_backup, nome)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remover_conexao", %{"conexao_id" => id}, socket) do
    if socket.assigns.is_admin do
      Admin.remover_conexao(id)
      grafo = Enciclopedia.listar_grafo()
      {:noreply, carregar_grafo(socket, grafo)}
    else
      {:noreply, socket}
    end
  end

  # ---------------------------------------------------------------------------
  # Privado
  # ---------------------------------------------------------------------------

  defp carregar_grafo(socket, %{nos: nos, arestas: arestas}) do
    graph_json =
      Jason.encode!(%{
        nodes: Enum.map(nos, fn p -> %{id: p.codigo, nome: p.nome} end),
        edges:
          Enum.map(arestas, fn c ->
            %{from: c.passo_origem.codigo, to: c.passo_destino.codigo, tipo: c.tipo}
          end)
      })

    socket
    |> assign(:nos, nos)
    |> assign(:arestas, arestas)
    |> assign(:arestas_por_origem, Enum.group_by(arestas, & &1.passo_origem_id))
    |> assign(:graph_json, graph_json)
  end

  defp toggle_selecao(set, id) do
    if MapSet.member?(set, id), do: MapSet.delete(set, id), else: MapSet.put(set, id)
  end

  defp nilify(""), do: nil
  defp nilify(value), do: value
end
