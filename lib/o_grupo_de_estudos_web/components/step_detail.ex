defmodule OGrupoDeEstudosWeb.StepDetail do
  @moduledoc """
  Componente único de detalhe de um passo do acervo.

  É a fonte de verdade visual e estrutural compartilhada entre a página interna
  (`/steps/:code`, `mode={:page}`) e o painel lateral da biblioteca
  (`CollectionLive`, `mode={:drawer}`). Apresenta cabeçalho, engajamento
  (curtir/favoritar), descrição técnica, conceitos, conexões compactas em chips,
  links/vídeos e comentários.

  É puramente apresentacional: recebe tudo por assigns e emite eventos
  (`phx-click`/`phx-submit`) que o LiveView hospedeiro trata. Os recursos
  exclusivos da página (sugestões campo a campo, gestão de links, formulário de
  conexão de entrada, despublicar/deletar) ficam atrás de `mode == :page`.
  """

  use OGrupoDeEstudosWeb, :html

  import OGrupoDeEstudosWeb.UI.CommentThread
  import OGrupoDeEstudosWeb.UI.InlineFollowButton

  alias OGrupoDeEstudosWeb.MediaEmbed

  @fallback_color "#9a7a5a"
  @connection_limit 10

  @step_image_overrides %{
    "SC" => "/images/collection/sacada-simples.png",
    "SC-E" => "/images/collection/sacada-esquerda.png",
    "SCSP" => "/images/collection/scsp.png",
    "GP" => "/images/collection/gp.png",
    "CA-E" => "/images/collection/caminhada.png",
    "IV" => "/images/collection/inversao.png",
    "TR-F" => "/images/collection/trava-frontal.png",
    "PE" => "/images/collection/pescada.png"
  }

  attr :mode, :atom, default: :page, values: [:page, :drawer]
  attr :step, :map, required: true
  attr :step_image, :string, default: nil
  attr :current_user, :map, required: true
  attr :is_admin, :boolean, default: false
  attr :can_edit, :boolean, default: false
  attr :edit_mode, :boolean, default: false
  attr :following_user_ids, :any, default: []
  attr :categories, :list, default: []

  attr :step_liked, :boolean, default: false
  attr :step_like_count, :integer, default: 0
  attr :step_favorited, :boolean, default: false

  attr :connections_out, :list, default: []
  attr :connections_in, :list, default: []
  attr :connections_expanded, :boolean, default: false

  attr :links, :list, default: []
  attr :link_likes, :map, default: %{liked_ids: MapSet.new(), counts: %{}}
  attr :expanded_video, :string, default: nil

  attr :comments, :list, default: []
  attr :comment_likes, :map, default: %{liked_ids: MapSet.new(), counts: %{}}
  attr :replies_map, :map, default: %{}
  attr :replying_to, :string, default: nil

  # Estado exclusivo da página (sugestões / gestão de links / conexões).
  attr :suggesting_field, :string, default: nil
  attr :suggestion_value, :string, default: ""
  attr :connection_search, :string, default: ""
  attr :connection_suggestions, :list, default: []
  attr :incoming_search, :string, default: ""
  attr :incoming_suggestions, :list, default: []
  attr :suggesting_connection, :boolean, default: false
  attr :connection_suggest_direction, :string, default: "to"
  attr :connection_suggest_search, :string, default: ""
  attr :connection_suggest_results, :list, default: []
  attr :my_pending_suggestions, :list, default: []
  attr :editing_link_id, :string, default: nil
  attr :editing_link_url, :string, default: ""
  attr :editing_link_title, :string, default: ""
  attr :link_url, :string, default: ""
  attr :link_title, :string, default: ""
  attr :link_submitted, :boolean, default: false

  def step_detail(assigns) do
    limit = @connection_limit

    assigns =
      assign(assigns,
        page?: assigns.mode == :page,
        conn_limit: limit,
        shown_out:
          visible_connections(assigns.connections_out, assigns.connections_expanded, limit),
        shown_in: visible_connections(assigns.connections_in, assigns.connections_expanded, limit)
      )

    ~H"""
    <article class={[
      "font-serif",
      @mode == :drawer && "px-5 py-6 md:px-7",
      @mode == :page && "w-full"
    ]}>
      <%!-- ───────── Header ───────── --%>
      <header class="mb-6">
        <%!-- No drawer, o host posiciona o botão de fechar (absolute, canto
        superior direito). Reservamos espaço com pr-12 para as ações do header
        não ficarem por baixo dele. --%>
        <div class={["flex items-start justify-between gap-3 mb-3", @mode == :drawer && "pr-12"]}>
          <div class="flex items-center gap-2.5 flex-wrap min-w-0">
            <code style={"font-family: monospace; font-size: 13px; font-weight: 700; color: #{category_color(@step)}; background: #{category_color(@step)}15; padding: 4px 10px; border-radius: 3px; border: 1px solid #{category_color(@step)}35; letter-spacing: 1px;"}>
              {@step.code}
            </code>
            <span style={"font-size: 12px; color: #{category_color(@step)}; background: #{category_color(@step)}15; padding: 3px 12px; border-radius: 10px; font-style: italic; border: 1px solid #{category_color(@step)}25;"}>
              {category_label(@step)}
            </span>
            <button
              :if={@page? && !@edit_mode && @suggesting_field != "category_id"}
              phx-click="start_suggest"
              phx-value-field="category_id"
              class="inline-flex p-0.5 text-ink-300 hover:text-accent-orange transition-colors"
              title="Sugerir edição da categoria"
            >
              <.icon name="hero-pencil-square" class="w-3.5 h-3.5" />
            </button>
            <span
              :if={@step.wip}
              class="text-[10px] text-accent-red bg-accent-red/10 py-0.5 px-2.5 rounded-full border border-accent-red/25 uppercase tracking-widest"
            >
              wip
            </span>
          </div>

          <div :if={@mode == :drawer} class="flex shrink-0 items-center gap-1.5">
            <button
              phx-click="copy_step_link"
              phx-value-code={@step.code}
              class="inline-flex h-8 w-8 items-center justify-center rounded-md border border-ink-200 text-ink-500 transition-colors hover:border-accent-orange/40 hover:text-accent-orange"
              title="Copiar link deste passo"
            >
              <.icon name="hero-link" class="size-3.5" />
            </button>
            <.link
              navigate={~p"/steps/#{@step.code}"}
              class="inline-flex h-8 w-8 items-center justify-center rounded-md border border-ink-200 text-ink-500 no-underline transition-colors hover:border-accent-orange/40 hover:text-accent-orange"
              title="Editar passo"
              aria-label="Editar passo"
            >
              <.icon name="hero-cog-6-tooth" class="size-3.5" />
            </.link>
          </div>
        </div>

        <%!-- Suggest category form (page) --%>
        <form
          :if={@page? && @suggesting_field == "category_id"}
          phx-submit="submit_suggestion"
          class="flex items-center gap-2 mt-1.5 mb-3"
        >
          <select
            name="value"
            class="flex-1 px-2.5 py-1.5 border border-accent-orange/40 rounded text-sm"
          >
            <option :for={cat <- @categories} value={cat.id} selected={cat.id == @step.category_id}>
              {cat.label}
            </option>
          </select>
          <button
            type="submit"
            class="text-xs bg-accent-orange text-white px-3 py-1.5 rounded font-medium border-0 cursor-pointer"
          >
            Enviar
          </button>
          <button
            type="button"
            phx-click="cancel_suggest"
            class="text-xs text-ink-400 px-2 py-1.5 cursor-pointer bg-transparent border-0"
          >
            Cancelar
          </button>
        </form>

        <%!-- Title --%>
        <div class="flex items-baseline gap-1">
          <h1 class={[
            "font-bold text-ink-900 tracking-tight leading-tight m-0",
            @mode == :page && "text-3xl",
            @mode == :drawer && "text-2xl"
          ]}>
            {@step.name}
          </h1>
          <button
            :if={@page? && !@edit_mode && @suggesting_field != "name"}
            phx-click="start_suggest"
            phx-value-field="name"
            class="inline-flex p-0.5 text-ink-300 hover:text-accent-orange transition-colors ml-1"
            title="Sugerir edição do nome"
          >
            <.icon name="hero-pencil-square" class="w-3.5 h-3.5" />
          </button>
        </div>

        <form
          :if={@page? && @suggesting_field == "name"}
          phx-submit="submit_suggestion"
          class="flex items-center gap-2 mt-1.5 mb-1"
        >
          <input
            name="value"
            value={@suggestion_value}
            required
            class="flex-1 px-2.5 py-1.5 border border-accent-orange/40 rounded text-sm text-ink-800 bg-ink-50 font-serif"
          />
          <button
            type="submit"
            class="text-xs bg-accent-orange text-white px-3 py-1.5 rounded font-medium border-0 cursor-pointer"
          >
            Enviar
          </button>
          <button
            type="button"
            phx-click="cancel_suggest"
            class="text-xs text-ink-400 px-2 py-1.5 cursor-pointer bg-transparent border-0"
          >
            Cancelar
          </button>
        </form>

        <%!-- Suggested-by badge --%>
        <div :if={@step.suggested_by_id} class="mt-2.5 flex items-center gap-2 flex-wrap">
          <.link
            navigate={~p"/users/#{if @step.suggested_by, do: @step.suggested_by.username, else: "#"}"}
            class="no-underline"
          >
            <span style={"font-size: 11px; padding: 3px 10px; border-radius: 10px; background: color-mix(in srgb, #{author_color(@step)} 8%, transparent); color: #{author_color(@step)}; border: 1px solid color-mix(in srgb, #{author_color(@step)} 19%, transparent);"}>
              <%= if @step.approved do %>
                ✓ Contribuição de @{if @step.suggested_by, do: @step.suggested_by.username, else: "?"}
              <% else %>
                Sugestão de @{if @step.suggested_by, do: @step.suggested_by.username, else: "?"}
              <% end %>
            </span>
          </.link>
          <.inline_follow_button
            target_user_id={@step.suggested_by_id}
            current_user_id={@current_user.id}
            following_user_ids={@following_user_ids}
          />
          <button
            :if={@is_admin and not @step.approved}
            phx-click="approve_step"
            phx-value-code={@step.code}
            data-confirm="Aprovar este passo como oficial?"
            class="inline-flex items-center text-[10px] py-1 px-2.5 rounded bg-accent-green text-white border-0 cursor-pointer"
          >
            Aprovar
          </button>
        </div>
      </header>

      <%!-- ───────── Engajamento ───────── --%>
      <div class="flex items-center gap-4 mb-6">
        <button
          phx-click="toggle_step_like"
          phx-value-id={@step.id}
          aria-label={if @step_liked, do: "Remover curtida deste passo", else: "Curtir este passo"}
          aria-pressed={to_string(@step_liked)}
          class="flex items-center gap-1.5 group"
        >
          <.icon
            name={if @step_liked, do: "hero-heart-solid", else: "hero-heart"}
            class={[
              "w-5 h-5 transition-all duration-200",
              @step_liked && "text-accent-red",
              !@step_liked && "text-ink-400 group-hover:text-accent-red/60"
            ]}
          />
          <span class={[
            "text-sm tabular-nums",
            @step_liked && "text-accent-red font-medium",
            !@step_liked && "text-ink-500"
          ]}>
            {if @step_like_count > 0, do: @step_like_count, else: "Curtir"}
          </span>
        </button>

        <button
          phx-click="toggle_step_favorite"
          phx-value-id={@step.id}
          aria-label={
            if @step_favorited, do: "Remover dos favoritos", else: "Adicionar aos favoritos"
          }
          aria-pressed={to_string(@step_favorited)}
          class="flex items-center gap-1.5 group"
        >
          <.icon
            name={if @step_favorited, do: "hero-star-solid", else: "hero-star"}
            class={[
              "w-5 h-5 transition-all duration-200",
              @step_favorited && "text-gold-500",
              !@step_favorited && "text-ink-400 group-hover:text-gold-500/60"
            ]}
          />
          <span class={[
            "text-sm",
            @step_favorited && "text-gold-500 font-medium",
            !@step_favorited && "text-ink-500"
          ]}>
            {if @step_favorited, do: "Favoritado", else: "Favoritar"}
          </span>
        </button>
      </div>

      <%!-- ───────── Edição (admin) OU descrição ───────── --%>
      <%= if @edit_mode and @can_edit do %>
        <.edit_form
          step={@step}
          categories={@categories}
          is_admin={@is_admin}
          page?={@page?}
        />
      <% else %>
        <div class="flex gap-6 flex-wrap mb-8">
          <div :if={@step_image} class="flex-shrink-0">
            <img
              src={@step_image}
              alt={@step.code}
              class="w-[160px] h-[160px] md:w-[200px] md:h-[200px] object-cover rounded-md border border-ink-900/15"
              style="filter: sepia(15%);"
              loading="lazy"
            />
          </div>
          <div class="flex-1 min-w-[220px]">
            <div class="flex items-center gap-1 mb-2.5">
              <p class="text-xs tracking-widest text-ink-500 uppercase m-0">Descrição técnica</p>
              <button
                :if={@page? && @suggesting_field != "note"}
                phx-click="start_suggest"
                phx-value-field="note"
                class="inline-flex p-0.5 text-ink-300 hover:text-accent-orange transition-colors"
                title="Sugerir edição da descrição"
              >
                <.icon name="hero-pencil-square" class="w-3.5 h-3.5" />
              </button>
            </div>
            <%= if @step.note do %>
              <p class="text-base leading-[1.9] text-ink-800 m-0">{@step.note}</p>
            <% else %>
              <p class="text-base text-ink-500 italic m-0">Sem descrição técnica ainda.</p>
            <% end %>

            <form
              :if={@page? && @suggesting_field == "note"}
              phx-submit="submit_suggestion"
              class="flex items-center gap-2 mt-2.5"
            >
              <input
                name="value"
                value={@suggestion_value}
                required
                class="flex-1 px-2.5 py-1.5 border border-accent-orange/40 rounded text-sm text-ink-800 bg-ink-50 font-serif"
              />
              <button
                type="submit"
                class="text-xs bg-accent-orange text-white px-3 py-1.5 rounded font-medium border-0 cursor-pointer"
              >
                Enviar
              </button>
              <button
                type="button"
                phx-click="cancel_suggest"
                class="text-xs text-ink-400 px-2 py-1.5 cursor-pointer bg-transparent border-0"
              >
                Cancelar
              </button>
            </form>

            <div
              :if={@step.last_edited_by_id && @step.last_edited_by}
              class="flex items-center gap-1.5 mt-3 text-xs text-ink-400"
            >
              <.icon name="hero-pencil" class="w-3 h-3" />
              <span>Editado por</span>
              <.link
                navigate={~p"/users/#{@step.last_edited_by.username}"}
                class="text-accent-orange font-medium no-underline hover:underline"
              >
                @{@step.last_edited_by.username}
              </.link>
              <.inline_follow_button
                target_user_id={@step.last_edited_by_id}
                current_user_id={@current_user.id}
                following_user_ids={@following_user_ids}
              />
            </div>
          </div>
        </div>
      <% end %>

      <%!-- ───────── Conceitos relacionados ───────── --%>
      <div
        :if={Map.get(@step, :technical_concepts, []) not in [[], nil]}
        class="mb-8 py-4 px-5 bg-gold-500/[0.08] border border-gold-500/25 border-l-[3px] border-l-gold-500 rounded-r-md"
      >
        <p class="text-xs tracking-widest text-ink-500 uppercase mb-3">Conceitos relacionados</p>
        <div :for={concept <- @step.technical_concepts} class="mb-2.5 last:mb-0">
          <p class="text-sm font-bold text-ink-900 mb-1">{concept.title}</p>
          <p class="text-sm text-ink-700 leading-relaxed m-0">{concept.description}</p>
        </div>
      </div>

      <%!-- ───────── Conexões (chips compactos) ───────── --%>
      <section class="mb-8">
        <div class="flex items-baseline justify-between mb-3">
          <p class="text-xs tracking-widest text-ink-500 uppercase m-0">Conexões</p>
          <span class="text-[11px] text-ink-500">
            {length(@connections_out)} saídas · {length(@connections_in)} entradas
          </span>
        </div>

        <div class="grid gap-5 sm:grid-cols-2">
          <div>
            <p class="text-[11px] font-semibold text-ink-600 mb-2">Vai para →</p>
            <p :if={@connections_out == []} class="text-sm text-ink-400 italic">Nenhuma saída</p>
            <div class="flex flex-wrap gap-1.5">
              <.connection_chip
                :for={conn <- @shown_out}
                step={conn.target_step}
                navigate={@page?}
                can_edit={@edit_mode and @can_edit}
                delete_event="delete_step_connection"
                delete_source={@step.code}
                delete_target={conn.target_step.code}
                suggest_event={if @page?, do: "suggest_remove_connection", else: nil}
                suggest_id={conn.id}
                suggest_label={"#{@step.code}→#{conn.target_step.code}"}
              />
              <button
                :if={length(@connections_out) > @conn_limit}
                type="button"
                phx-click="toggle_connections"
                class="rounded-lg border border-dashed border-ink-300 px-2 py-1 text-[11px] text-ink-500 transition hover:border-ink-400 hover:text-ink-700"
              >
                {if @connections_expanded,
                  do: "ver menos",
                  else: "+#{length(@connections_out) - @conn_limit} mais"}
              </button>
            </div>
          </div>

          <div>
            <p class="text-[11px] font-semibold text-ink-600 mb-2">← Vem de</p>
            <p :if={@connections_in == []} class="text-sm text-ink-400 italic">Nenhuma entrada</p>
            <div class="flex flex-wrap gap-1.5">
              <.connection_chip
                :for={conn <- @shown_in}
                step={conn.source_step}
                navigate={@page?}
                can_edit={@edit_mode and @can_edit}
                delete_event="delete_step_connection"
                delete_source={conn.source_step.code}
                delete_target={@step.code}
                suggest_event={if @page?, do: "suggest_remove_connection", else: nil}
                suggest_id={conn.id}
                suggest_label={"#{conn.source_step.code}→#{@step.code}"}
              />
              <button
                :if={length(@connections_in) > @conn_limit}
                type="button"
                phx-click="toggle_connections"
                class="rounded-lg border border-dashed border-ink-300 px-2 py-1 text-[11px] text-ink-500 transition hover:border-ink-400 hover:text-ink-700"
              >
                {if @connections_expanded,
                  do: "ver menos",
                  else: "+#{length(@connections_in) - @conn_limit} mais"}
              </button>
            </div>
          </div>
        </div>

        <%!-- Add connection (admin, outgoing) --%>
        <div :if={@edit_mode and @can_edit} class="mt-3 relative">
          <form
            phx-submit="create_step_connection"
            phx-change="search_connection"
            class="flex gap-1.5"
          >
            <input
              type="text"
              name="target_code"
              value={@connection_search}
              placeholder="Buscar passo por código ou nome..."
              autocomplete="off"
              phx-debounce="150"
              class="flex-1 py-2 px-3 border border-ink-300 rounded font-serif text-sm text-ink-900"
            />
            <button
              type="submit"
              class="py-2 px-3.5 bg-ink-900 text-ink-100 border-0 rounded cursor-pointer text-xs whitespace-nowrap"
            >
              + Saída
            </button>
          </form>
          <div
            :if={@connection_suggestions != []}
            class="absolute top-[42px] left-0 right-[60px] bg-ink-50 border border-ink-300 rounded shadow-lg z-10 max-h-[200px] overflow-y-auto"
          >
            <div
              :for={sug <- @connection_suggestions}
              phx-click="select_connection_target"
              phx-value-code={sug.code}
              class="py-2 px-3 cursor-pointer border-b border-ink-200/40 font-serif text-sm text-ink-900 hover:bg-ink-200/60"
            >
              <code style={"color: #{chip_color(sug)};"} class="text-[11px] mr-1.5">{sug.code}</code>
              {sug.name}
            </div>
          </div>
        </div>

        <%!-- Add incoming connection (admin, page only) --%>
        <div :if={@page? and @edit_mode and @can_edit} class="mt-2 relative">
          <form
            phx-submit="create_incoming_connection"
            phx-change="search_incoming_connection"
            class="flex gap-1.5"
          >
            <input
              type="text"
              name="source_code"
              value={@incoming_search}
              placeholder="Buscar passo de entrada..."
              autocomplete="off"
              phx-debounce="150"
              class="flex-1 py-2 px-3 border border-ink-300 rounded font-serif text-sm text-ink-900"
            />
            <button
              type="submit"
              class="py-2 px-3.5 bg-ink-900 text-ink-100 border-0 rounded cursor-pointer text-xs whitespace-nowrap"
            >
              + Entrada
            </button>
          </form>
          <div
            :if={@incoming_suggestions != []}
            class="absolute top-[42px] left-0 right-[60px] bg-ink-50 border border-ink-300 rounded shadow-lg z-10 max-h-[200px] overflow-y-auto"
          >
            <div
              :for={sug <- @incoming_suggestions}
              phx-click="select_incoming_target"
              phx-value-code={sug.code}
              class="py-2 px-3 cursor-pointer border-b border-ink-200/40 font-serif text-sm text-ink-900 hover:bg-ink-200/60"
            >
              <code style={"color: #{chip_color(sug)};"} class="text-[11px] mr-1.5">{sug.code}</code>
              {sug.name}
            </div>
          </div>
        </div>

        <%!-- Suggest connection (page, non-edit) --%>
        <button
          :if={@page? && !@edit_mode && !@suggesting_connection}
          phx-click="start_suggest_connection"
          class="text-xs text-accent-orange hover:text-accent-orange/80 mt-3 cursor-pointer bg-transparent border-0 font-serif"
        >
          + Sugerir nova conexão
        </button>
        <div
          :if={@page? && @suggesting_connection}
          class="mt-2 p-2 bg-ink-50 rounded border border-ink-200"
        >
          <div class="flex gap-1 mb-2">
            <button
              type="button"
              phx-click="set_connection_direction"
              phx-value-direction="to"
              class={[
                "text-[10px] font-semibold py-1 px-3 rounded-full border cursor-pointer transition-colors",
                @connection_suggest_direction == "to" &&
                  "bg-accent-orange border-accent-orange text-white",
                @connection_suggest_direction != "to" && "bg-transparent border-ink-300 text-ink-500"
              ]}
            >
              Vai para →
            </button>
            <button
              type="button"
              phx-click="set_connection_direction"
              phx-value-direction="from"
              class={[
                "text-[10px] font-semibold py-1 px-3 rounded-full border cursor-pointer transition-colors",
                @connection_suggest_direction == "from" &&
                  "bg-accent-orange border-accent-orange text-white",
                @connection_suggest_direction != "from" &&
                  "bg-transparent border-ink-300 text-ink-500"
              ]}
            >
              ← Vem de
            </button>
          </div>
          <input
            type="text"
            phx-keyup="search_suggest_connection"
            phx-debounce="200"
            value={@connection_suggest_search}
            placeholder="Buscar passo..."
            class="w-full px-2 py-1.5 border border-ink-300 rounded text-xs"
          />
          <div :if={@connection_suggest_results != []} class="mt-1 space-y-0.5">
            <button
              :for={result <- @connection_suggest_results}
              phx-click="submit_connection_suggestion"
              phx-value-target_code={result.code}
              class="block w-full text-left px-2 py-1 text-xs hover:bg-ink-100 rounded cursor-pointer bg-transparent border-0"
            >
              <code class="text-accent-orange">{result.code}</code> {result.name}
            </button>
          </div>
          <button
            phx-click="cancel_suggest_connection"
            class="text-xs text-ink-400 mt-1 cursor-pointer bg-transparent border-0"
          >
            Cancelar
          </button>
        </div>
      </section>

      <%!-- Pending suggestions (page only) --%>
      <div
        :if={@page? && @my_pending_suggestions != []}
        class="mb-8 rounded-lg border border-amber-500/25 bg-amber-500/[0.06] p-4"
      >
        <p class="text-[10px] font-bold text-amber-600 uppercase tracking-wider m-0 mb-2">
          Suas sugestões pendentes
        </p>
        <p class="text-xs text-ink-500 m-0 mb-3">
          Aguardando aprovação do administrador (até 2 dias úteis).
        </p>
        <div class="space-y-2">
          <div
            :for={sug <- @my_pending_suggestions}
            class="flex items-start gap-2 rounded border border-amber-500/15 bg-ink-50 px-3 py-2"
          >
            <span class="mt-0.5 text-amber-500">
              <.icon name="hero-clock" class="size-3.5" />
            </span>
            <div class="min-w-0 flex-1 text-xs text-ink-700">
              <%= cond do %>
                <% sug.action == "edit_field" -> %>
                  <span class="font-semibold">{sug.field}</span>:
                  <span class="line-through text-ink-400">{sug.old_value}</span>
                  <span class="text-ink-400">→</span>
                  <span class="font-semibold text-accent-green">{sug.new_value}</span>
                <% sug.action == "create_connection" -> %>
                  Nova conexão: <span class="font-semibold text-accent-green">{sug.new_value}</span>
                <% sug.action == "remove_connection" -> %>
                  Remover conexão:
                  <span class="font-semibold text-accent-red line-through">{sug.old_value}</span>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <%!-- ───────── Links / vídeos ───────── --%>
      <.detail_links
        mode={@mode}
        page?={@page?}
        links={@links}
        link_likes={@link_likes}
        expanded_video={@expanded_video}
        is_admin={@is_admin}
        edit_mode={@edit_mode}
        current_user={@current_user}
        editing_link_id={@editing_link_id}
        editing_link_url={@editing_link_url}
        editing_link_title={@editing_link_title}
        link_url={@link_url}
        link_title={@link_title}
        link_submitted={@link_submitted}
      />

      <%!-- ───────── Comentários ───────── --%>
      <section class="mt-8 pt-6 border-t border-ink-200">
        <h3 class="text-lg font-serif font-bold text-ink-800 mb-4">
          Comentários
          <span
            :if={length(@comments) > 0}
            class="text-sm font-sans font-normal text-ink-400 ml-1"
          >
            ({length(@comments)})
          </span>
        </h3>
        <.comment_thread
          comments={@comments}
          current_user={@current_user}
          likes_map={@comment_likes}
          comment_type="step_comment"
          parent_id={@step.id}
          replying_to={@replying_to}
          replies_map={@replies_map}
          is_admin={@is_admin}
        />
      </section>
    </article>
    """
  end

  # ───────── Edit form (admin) ─────────

  attr :step, :map, required: true
  attr :categories, :list, default: []
  attr :is_admin, :boolean, default: false
  attr :page?, :boolean, default: true

  defp edit_form(assigns) do
    ~H"""
    <form phx-submit="update_step" class="mb-8 p-5 bg-ink-50 border border-ink-900/10 rounded-md">
      <div class="flex flex-col gap-3.5">
        <div class="flex gap-3 flex-wrap">
          <div class="flex-1 min-w-[160px]">
            <label class="text-xs text-ink-700 uppercase tracking-widest font-semibold block mb-1">
              Nome
            </label>
            <input
              type="text"
              name="step[name]"
              value={@step.name}
              class="w-full py-2.5 px-3 border border-ink-900/30 rounded font-serif text-base text-ink-900 box-border"
            />
          </div>
          <div class="w-[120px]">
            <label class="text-xs text-ink-700 uppercase tracking-widest font-semibold block mb-1">
              Código
            </label>
            <input
              type="text"
              name="step[code]"
              value={@step.code}
              class="w-full py-2.5 px-3 border border-ink-900/30 rounded font-mono text-base text-ink-900 box-border"
            />
          </div>
        </div>
        <div>
          <label class="text-xs text-ink-700 uppercase tracking-widest font-semibold block mb-1">
            Descrição técnica
          </label>
          <textarea
            name="step[note]"
            rows="5"
            class="w-full py-2.5 px-3 border border-ink-900/30 rounded font-serif text-base text-ink-900 box-border resize-y leading-relaxed"
          ><%= @step.note %></textarea>
        </div>
        <div class="flex gap-3 flex-wrap">
          <div class="flex-1 min-w-[160px]">
            <label class="text-xs text-ink-700 uppercase tracking-widest font-semibold block mb-1">
              Categoria
            </label>
            <select
              name="step[category_id]"
              class="w-full py-2.5 px-3 border border-ink-900/30 rounded font-serif text-base text-ink-900"
            >
              <option :for={cat <- @categories} value={cat.id} selected={cat.id == @step.category_id}>
                {cat.label}
              </option>
            </select>
          </div>
          <div class="flex items-end gap-2.5 pb-1">
            <label class="text-sm text-ink-700 flex items-center gap-1">
              <input type="hidden" name="step[wip]" value="false" />
              <input type="checkbox" name="step[wip]" value="true" checked={@step.wip} /> WIP
            </label>
            <label class="text-sm text-ink-700 flex items-center gap-1">
              <input type="hidden" name="step[highlighted]" value="false" />
              <input
                type="checkbox"
                name="step[highlighted]"
                value="true"
                checked={@step.highlighted}
              /> Destacado
            </label>
          </div>
        </div>
        <div class="flex gap-3 items-center flex-wrap">
          <button
            type="submit"
            class="py-2.5 px-5 bg-ink-900 text-ink-100 border-0 rounded-md cursor-pointer font-serif text-sm font-semibold tracking-wide"
          >
            Salvar alterações
          </button>
          <button
            :if={@page? && @is_admin && @step.suggested_by_id && @step.approved}
            type="button"
            phx-click="unapprove_step"
            data-confirm={"Desaprovar o passo \"#{@step.name}\"? Ele vai sair do acervo público."}
            class="py-2.5 px-5 bg-transparent border-2 border-accent-orange text-accent-orange rounded-md cursor-pointer font-serif text-sm font-semibold tracking-wide"
          >
            Desaprovar
          </button>
          <button
            :if={@page? && @is_admin}
            type="button"
            phx-click="delete_step"
            data-confirm={"Tem certeza que deseja deletar o passo \"#{@step.name}\" (#{@step.code})? Todas as conexões serão removidas. Esta ação é irreversível."}
            class="py-2.5 px-5 bg-transparent border-2 border-accent-red text-accent-red rounded-md cursor-pointer font-serif text-sm font-semibold tracking-wide"
          >
            Deletar passo
          </button>
        </div>
      </div>
    </form>
    """
  end

  # ───────── Links / vídeos ─────────

  attr :mode, :atom, default: :page
  attr :page?, :boolean, default: true
  attr :links, :list, default: []
  attr :link_likes, :map, default: %{liked_ids: MapSet.new(), counts: %{}}
  attr :expanded_video, :string, default: nil
  attr :is_admin, :boolean, default: false
  attr :edit_mode, :boolean, default: false
  attr :current_user, :map, required: true
  attr :editing_link_id, :string, default: nil
  attr :editing_link_url, :string, default: ""
  attr :editing_link_title, :string, default: ""
  attr :link_url, :string, default: ""
  attr :link_title, :string, default: ""
  attr :link_submitted, :boolean, default: false

  defp detail_links(assigns) do
    ~H"""
    <section class="mb-2">
      <p class="text-xs tracking-widest text-ink-500 uppercase mb-3">Links e vídeos</p>

      <p :if={@links == []} class="text-sm text-ink-400 italic mb-4">Nenhum link ainda.</p>

      <div :if={@links != []} class="flex flex-col gap-3 mb-4">
        <div :for={link <- @links}>
          <% liked = MapSet.member?(@link_likes.liked_ids, link.id) %>
          <% like_count = Map.get(@link_likes.counts, link.id, 0) %>
          <% can_edit_link =
            @page? and @edit_mode and (@is_admin or link.submitted_by_id == @current_user.id) %>
          <%= if @page? && @editing_link_id == link.id do %>
            <form
              phx-submit="update_link"
              class="p-3 bg-ink-50 border-2 border-gold-500 rounded-md flex flex-col gap-2"
            >
              <input
                type="text"
                name="title"
                value={@editing_link_title}
                placeholder="Título do link"
                class="w-full py-2 px-2.5 border border-ink-900/30 rounded font-serif text-sm text-ink-900 box-border"
              />
              <input
                type="url"
                name="url"
                value={@editing_link_url}
                required
                class="w-full py-2 px-2.5 border border-ink-900/30 rounded font-serif text-sm text-ink-900 box-border"
              />
              <div class="flex gap-2">
                <button
                  type="submit"
                  class="py-1.5 px-3.5 bg-ink-900 text-ink-100 border-0 rounded cursor-pointer font-serif text-xs font-semibold"
                >
                  Salvar
                </button>
                <button
                  type="button"
                  phx-click="cancel_edit_link"
                  class="py-1.5 px-3.5 bg-transparent text-ink-700 border border-ink-900/30 rounded cursor-pointer font-serif text-xs"
                >
                  Cancelar
                </button>
              </div>
            </form>
          <% else %>
            <% media = MediaEmbed.resolve(link.url) %>
            <% expanded = @expanded_video == link.id %>
            <div class="rounded-md border border-ink-900/12 bg-ink-50 overflow-hidden">
              <div class="flex items-center gap-2.5 py-2.5 px-3">
                <span class="text-base flex-shrink-0" aria-hidden="true">
                  {if media.kind == :embed, do: "▶", else: "🔗"}
                </span>
                <div class="min-w-0 flex-1">
                  <p class="text-sm font-semibold text-ink-900 m-0 mb-1 whitespace-nowrap overflow-hidden text-ellipsis">
                    {if link.title && link.title != "", do: link.title, else: media.label}
                  </p>
                  <a
                    href={link.url}
                    target="_blank"
                    rel="noreferrer noopener"
                    class="inline-flex items-center gap-0.5 rounded-full px-2.5 py-0.5 text-[11px] font-semibold no-underline"
                    style={provider_pill(media)}
                    title={"Abrir no #{media.label}"}
                  >
                    {media.label} ↗
                  </a>
                </div>
                <button
                  :if={can_edit_link}
                  phx-click="start_edit_link"
                  phx-value-link-id={link.id}
                  class="bg-transparent border-0 cursor-pointer text-sm text-gold-500 py-1 px-1.5 flex-shrink-0"
                  title="Editar link"
                >
                  ✏
                </button>
                <button
                  :if={can_edit_link}
                  phx-click="delete_link"
                  phx-value-link-id={link.id}
                  data-confirm="Remover este link?"
                  class="bg-transparent border-0 cursor-pointer text-base text-accent-red py-1 px-1.5 flex-shrink-0"
                  title="Remover link"
                >
                  ×
                </button>
                <button
                  phx-click="toggle_link_like"
                  phx-value-link-id={link.id}
                  class={[
                    "flex items-center gap-1 bg-transparent border-0 cursor-pointer text-sm py-1 px-1.5 rounded flex-shrink-0",
                    liked && "text-accent-red",
                    !liked && "text-ink-500"
                  ]}
                  title={if liked, do: "Remover like", else: "Curtir"}
                >
                  {if liked, do: "♥", else: "♡"}
                  <span :if={like_count > 0} class="text-xs">{like_count}</span>
                </button>
                <button
                  :if={media.kind == :embed}
                  phx-click="toggle_link_video"
                  phx-value-link-id={link.id}
                  class={[
                    "text-xs py-1 px-2.5 rounded cursor-pointer border border-ink-900/20 text-ink-700 whitespace-nowrap font-serif flex-shrink-0",
                    expanded && "bg-ink-900/[0.06]",
                    !expanded && "bg-transparent"
                  ]}
                >
                  {if expanded, do: "▲ Fechar", else: "▶ Ver"}
                </button>
              </div>
              <.media_player :if={expanded and media.kind == :embed} media={media} url={link.url} />
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Submit link (page only) --%>
      <div :if={@page?} class="py-4 px-4 bg-gold-500/[0.06] border border-gold-500/20 rounded-md">
        <p class="text-xs tracking-[1.5px] text-ink-500 uppercase mb-3">Adicionar link</p>
        <form phx-submit="submit_link" class="flex flex-col gap-2">
          <input
            type="url"
            name="url"
            value={@link_url}
            placeholder="https://..."
            required
            class="w-full py-2 px-3 border border-ink-900/25 rounded font-serif text-sm text-ink-900 box-border"
          />
          <input
            type="text"
            name="title"
            value={@link_title}
            placeholder="Título opcional"
            class="w-full py-2 px-3 border border-ink-900/25 rounded font-serif text-sm text-ink-900 box-border"
          />
          <div>
            <button
              type="submit"
              class="py-2 px-4 bg-ink-900 text-ink-100 border-0 rounded-md cursor-pointer font-serif text-sm font-semibold tracking-wide"
            >
              Enviar link
            </button>
          </div>
        </form>
        <p :if={@link_submitted} class="text-sm text-accent-green mt-2.5 italic">
          Link enviado para aprovação!
        </p>
      </div>
    </section>
    """
  end

  # ───────── Player de mídia (embed por formato) ─────────

  attr :media, :map, required: true
  attr :url, :string, required: true

  defp media_player(assigns) do
    ~H"""
    <div>
      <div :if={@media.shape == :wide} class="relative h-0 overflow-hidden bg-ink-900 pb-[56.25%]">
        <iframe
          src={@media.embed_url}
          frameborder="0"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
          allowfullscreen
          loading="lazy"
          class="absolute inset-0 h-full w-full"
        >
        </iframe>
      </div>
      <div :if={@media.shape == :tall} class="mx-auto w-full max-w-[320px]">
        <div class="relative h-0 overflow-hidden bg-ink-900 pb-[177.78%]">
          <iframe
            src={@media.embed_url}
            frameborder="0"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowfullscreen
            loading="lazy"
            class="absolute inset-0 h-full w-full"
          >
          </iframe>
        </div>
      </div>
      <div :if={@media.shape == :portrait} class="mx-auto w-full max-w-[400px] bg-ink-50">
        <iframe
          src={@media.embed_url}
          scrolling="no"
          loading="lazy"
          class="w-full border-0"
          style="height: 640px"
        >
        </iframe>
      </div>
      <a
        href={@url}
        target="_blank"
        rel="noreferrer noopener"
        class="flex items-center justify-center gap-1.5 border-t border-ink-900/10 py-2 text-xs text-ink-500 no-underline transition-colors hover:text-accent-orange"
      >
        <.icon name="hero-arrow-top-right-on-square" class="w-3.5 h-3.5" /> Abrir no {@media.label}
      </a>
    </div>
    """
  end

  # Estilo do pill do provedor (cálculo puro): tom da marca com baixa opacidade.
  defp provider_pill(media) do
    color = provider_color(media)
    "background: #{color}14; color: #{color}; border: 1px solid #{color}33;"
  end

  defp provider_color(%{label: "Instagram"}), do: "#c13584"
  defp provider_color(%{label: "YouTube" <> _}), do: "#c0392b"
  defp provider_color(_), do: "#7a5c3a"

  # ───────── Connection chip ─────────

  @doc """
  Chip compacto de conexão: badge de código tingido pela categoria + nome.
  Abre o passo (navegando em `mode={:page}` ou via `open_step` no drawer). Mostra
  uma afordância de remover para admin/edição, ou de sugerir remoção fora de edição.
  """
  attr :step, :map, required: true
  attr :navigate, :boolean, default: false
  attr :can_edit, :boolean, default: false
  attr :delete_event, :string, default: "delete_step_connection"
  attr :delete_source, :string, default: nil
  attr :delete_target, :string, default: nil
  attr :suggest_event, :string, default: nil
  attr :suggest_id, :string, default: nil
  attr :suggest_label, :string, default: nil

  def connection_chip(assigns) do
    assigns = assign(assigns, :color, chip_color(assigns.step))

    ~H"""
    <span
      class="inline-flex items-center overflow-hidden rounded-lg border bg-ink-50 transition hover:bg-ink-200/50"
      style={"border-color: #{@color}40;"}
    >
      <.link
        :if={@navigate}
        navigate={~p"/steps/#{@step.code}"}
        class="inline-flex max-w-[200px] items-center gap-1.5 px-2 py-1 text-left no-underline"
      >
        <code class="shrink-0 text-[10px] font-bold" style={"color: #{@color};"}>{@step.code}</code>
        <span class="truncate text-xs text-ink-700">{@step.name}</span>
      </.link>
      <button
        :if={!@navigate}
        phx-click="open_step"
        phx-value-code={@step.code}
        class="inline-flex max-w-[200px] items-center gap-1.5 px-2 py-1 text-left"
      >
        <code class="shrink-0 text-[10px] font-bold" style={"color: #{@color};"}>{@step.code}</code>
        <span class="truncate text-xs text-ink-700">{@step.name}</span>
      </button>
      <button
        :if={@can_edit}
        phx-click={@delete_event}
        phx-value-source={@delete_source}
        phx-value-target={@delete_target}
        data-confirm={"Remover #{@delete_source} → #{@delete_target}?"}
        class="self-stretch border-l border-ink-200 px-1.5 text-accent-red/70 transition hover:bg-accent-red/10 hover:text-accent-red"
      >
        ×
      </button>
      <button
        :if={!@can_edit and @suggest_event}
        phx-click={@suggest_event}
        phx-value-id={@suggest_id}
        phx-value-label={@suggest_label}
        data-confirm="Sugerir remoção desta conexão?"
        title="Sugerir remoção"
        class="self-stretch border-l border-ink-200 px-1.5 text-ink-300 transition hover:text-accent-red"
      >
        <.icon name="hero-x-mark" class="w-3 h-3" />
      </button>
    </span>
    """
  end

  # ───────── Helpers (cálculos puros) ─────────

  @doc "Resolve a imagem de capa de um passo, aplicando overrides por código."
  def resolve_step_image(step) do
    case Map.get(@step_image_overrides, step.code) do
      nil -> normalize_image_path(step.image_path)
      override -> override
    end
  end

  defp normalize_image_path(nil), do: nil
  defp normalize_image_path("/" <> _ = path), do: path
  defp normalize_image_path(path), do: "/" <> path

  @doc "Cor da categoria do passo, com fallback sépia."
  def category_color(%{category: %{color: color}}) when is_binary(color), do: color
  def category_color(_), do: "#7f8c8d"

  def category_label(%{category: %{label: label}}) when is_binary(label), do: label
  def category_label(_), do: "—"

  defp chip_color(%{category: %{color: color}}) when is_binary(color), do: color
  defp chip_color(_), do: @fallback_color

  defp author_color(%{approved: true}), do: "var(--color-accent-green)"
  defp author_color(_), do: "var(--color-accent-purple)"

  defp visible_connections(connections, true, _limit), do: connections
  defp visible_connections(connections, false, limit), do: Enum.take(connections, limit)
end
