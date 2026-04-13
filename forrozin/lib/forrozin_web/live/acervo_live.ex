defmodule ForrozinWeb.AcervoLive do
  @moduledoc """
  Enciclopédia de passos de forró roots.

  Requer autenticação. A visibilidade dos passos wip/rascunho é controlada
  no contexto `Enciclopedia`, nunca aqui.
  """

  use ForrozinWeb, :live_view

  alias Forrozin.Accounts
  alias Forrozin.Enciclopedia

  on_mount {ForrozinWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    admin = Accounts.admin?(socket.assigns.current_user)
    secoes = Enciclopedia.listar_secoes_com_passos(admin: admin)
    categorias = Enciclopedia.listar_categorias()
    secoes_abertas = Map.new(secoes, fn s -> {s.id, false} end)

    socket =
      assign(socket,
        secoes: secoes,
        categorias: categorias,
        secoes_abertas: secoes_abertas,
        busca: "",
        resultados_busca: [],
        categoria_filtro: "all",
        email_confirmado: Accounts.email_confirmado?(socket.assigns.current_user),
        page_title: "Acervo"
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("buscar", %{"termo" => termo}, socket) do
    admin = Accounts.admin?(socket.assigns.current_user)
    resultados = if termo == "", do: [], else: Enciclopedia.buscar_passos(termo, admin: admin)
    {:noreply, assign(socket, busca: termo, resultados_busca: resultados)}
  end

  def handle_event("filtrar", %{"categoria" => categoria}, socket) do
    {:noreply, assign(socket, categoria_filtro: categoria)}
  end

  def handle_event("toggle_secao", %{"secao_id" => id}, socket) do
    secoes_abertas = Map.update(socket.assigns.secoes_abertas, id, true, fn a -> !a end)
    {:noreply, assign(socket, secoes_abertas: secoes_abertas)}
  end

  def handle_event("expandir_tudo", _params, socket) do
    secoes_abertas = Map.new(socket.assigns.secoes, fn s -> {s.id, true} end)
    {:noreply, assign(socket, secoes_abertas: secoes_abertas)}
  end

  def handle_event("recolher_tudo", _params, socket) do
    secoes_abertas = Map.new(socket.assigns.secoes, fn s -> {s.id, false} end)
    {:noreply, assign(socket, secoes_abertas: secoes_abertas)}
  end

  # ---------------------------------------------------------------------------
  # Componentes
  # ---------------------------------------------------------------------------

  attr :secao, :map, required: true
  attr :aberta, :boolean, required: true

  def secao_card(assigns) do
    ~H"""
    <div
      class="mb-2 rounded overflow-hidden"
      style={"border: 1px solid #{if @aberta, do: "rgba(60,40,20,0.2)", else: "rgba(60,40,20,0.1)"}; background: #{if @aberta, do: "#fffef9", else: "#fdfcf7"}"}
    >
      <button
        phx-click="toggle_secao"
        phx-value-secao_id={@secao.id}
        class="w-full text-left flex items-center gap-3 px-5 py-3"
        style="background: transparent; border: none; cursor: pointer;"
      >
        <span style={"color: #{categoria_cor(@secao)}; font-size: 10px; display: inline-block; transform: #{if @aberta, do: "rotate(90deg)", else: "rotate(0deg)"}; transition: transform 0.15s;"}>
          ▶
        </span>
        <span class="flex items-center gap-3 flex-wrap flex-1">
          <%= if @secao.num do %>
            <span style="font-size: 11px; color: #aaa; font-family: Georgia, serif; font-style: italic;">
              {@secao.num}.
            </span>
          <% end %>
          <%= if @secao.codigo do %>
            <code style={"font-size: 11px; color: #{categoria_cor(@secao)}; background: #{categoria_cor(@secao)}15; padding: 2px 8px; border-radius: 3px; border: 1px solid #{categoria_cor(@secao)}30; letter-spacing: 0.5px;"}>
              {@secao.codigo}
            </code>
          <% end %>
          <span style="font-size: 15px; font-weight: 700; color: #1a0e05; font-family: Georgia, serif; letter-spacing: -0.2px;">
            {@secao.titulo}
          </span>
          <span style={"font-size: 10px; color: #{categoria_cor(@secao)}; background: #{categoria_cor(@secao)}15; padding: 1px 8px; border-radius: 10px; font-family: Georgia, serif; font-style: italic; border: 1px solid #{categoria_cor(@secao)}25;"}>
            {rotulo_categoria(@secao)}
          </span>
        </span>
      </button>
      <%= if @aberta do %>
        <div style="padding: 4px 24px 20px 54px;">
          <%= if @secao.descricao do %>
            <p style="font-size: 13px; color: #7a5c3a; font-style: italic; margin-bottom: 12px; line-height: 1.7; font-family: Georgia, serif;">
              {@secao.descricao}
            </p>
          <% end %>
          <%= if @secao.nota do %>
            <div style="font-size: 12px; color: #5c3a1a; background: rgba(212,160,84,0.1); border: 1px solid rgba(212,160,84,0.3); border-left: 3px solid #d4a054; border-radius: 0 4px 4px 0; padding: 8px 14px; margin: 0 0 14px; font-family: Georgia, serif; font-style: italic; line-height: 1.7;">
              {@secao.nota}
            </div>
          <% end %>
          <%= for passo <- @secao.passos do %>
            <.passo_item passo={passo} />
          <% end %>
          <%= for subsecao <- @secao.subsecoes do %>
            <div style="margin-top: 16px;">
              <div style="font-size: 10px; font-weight: 700; color: #9a7a5a; font-family: Georgia, serif; text-transform: uppercase; letter-spacing: 2px; margin-bottom: 10px; padding-bottom: 6px; border-bottom: 1px solid rgba(60,40,20,0.1);">
                {subsecao.titulo}
              </div>
              <%= if subsecao.nota do %>
                <p style="font-size: 12px; color: #7a5c3a; font-style: italic; margin-bottom: 10px; font-family: Georgia, serif;">
                  {subsecao.nota}
                </p>
              <% end %>
              <%= for passo <- subsecao.passos do %>
                <.passo_item passo={passo} />
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :passo, :map, required: true

  def passo_item(assigns) do
    ~H"""
    <.link
      navigate={~p"/passos/#{@passo.codigo}"}
      style="display: flex; gap: 14px; padding: 12px 0; border-bottom: 1px solid rgba(60,40,20,0.12); text-decoration: none; color: inherit;"
    >
      <%= if @passo.caminho_imagem do %>
        <img
          src={"/#{@passo.caminho_imagem}"}
          alt={@passo.codigo}
          loading="lazy"
          style="width: 72px; height: 72px; object-fit: cover; border-radius: 4px; flex-shrink: 0; border: 1px solid rgba(60,40,20,0.15); filter: sepia(20%);"
        />
      <% end %>
      <div style="flex: 1;">
        <div style="display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap;">
          <code style="font-family: 'Courier New', monospace; font-size: 12px; font-weight: 700; color: #5c3a1a; background: rgba(180,120,40,0.1); padding: 2px 7px; border-radius: 3px; letter-spacing: 0.5px; border: 1px solid rgba(180,120,40,0.2);">
            {@passo.codigo}
          </code>
          <span style="font-size: 14px; color: #2c1a0e; font-family: Georgia, serif; line-height: 1.5;">
            {@passo.nome}
          </span>
        </div>
        <%= if @passo.nota do %>
          <p style="font-size: 12px; color: #7a5c3a; margin: 5px 0 0; font-family: Georgia, serif; font-style: italic; line-height: 1.6;">
            {String.slice(@passo.nota, 0, 120)}{if String.length(@passo.nota) > 120, do: "…"}
          </p>
        <% end %>
      </div>
    </.link>
    """
  end

  # ---------------------------------------------------------------------------
  # Helpers públicos (usados no template)
  # ---------------------------------------------------------------------------

  def secoes_filtradas(secoes, "all"), do: secoes

  def secoes_filtradas(secoes, categoria) do
    Enum.filter(secoes, fn s ->
      s.categoria != nil and s.categoria.nome == categoria
    end)
  end

  def total_passos(secoes) do
    Enum.reduce(secoes, 0, fn s, acc ->
      sub_total = Enum.reduce(s.subsecoes, 0, fn sub, n -> n + length(sub.passos) end)
      acc + length(s.passos) + sub_total
    end)
  end

  def categoria_cor(%{categoria: %{cor: cor}}), do: cor
  def categoria_cor(_), do: "#7f8c8d"

  def rotulo_categoria(%{categoria: %{rotulo: rotulo}}), do: rotulo
  def rotulo_categoria(_), do: ""
end
