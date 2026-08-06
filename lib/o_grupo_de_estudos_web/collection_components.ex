defmodule OGrupoDeEstudosWeb.CollectionComponents do
  @moduledoc """
  Function components for the collection (acervo) view.

  Holds the `step_item/1` row used in search and "Meus passos" listings. Clicking
  a row opens the shared step drawer (`open_step`), where the full
  `OGrupoDeEstudosWeb.StepDetail` experience is rendered.
  """

  use OGrupoDeEstudosWeb, :html

  import OGrupoDeEstudosWeb.UI.Illustration, only: [illustration: 1]

  alias OGrupoDeEstudosWeb.UI.Illustration

  @doc """
  The square that identifies a family: its drawing, or its code when there is none.

  Only ten of the twenty-one families were ever drawn, so half the list would
  open a hole. The code is not a placeholder standing in for the drawing, it is
  what people say out loud in class, so the undrawn half still says who it is.
  """
  attr :card, :map, required: true

  def family_mark(%{card: %{image_path: nil}} = assigns) do
    ~H"""
    <span class="grid size-[54px] shrink-0 place-items-center rounded-lg border border-ink-300/50 bg-ink-200 font-sans text-[13px] font-semibold tracking-tight text-ink-600">
      {family_mark_label(@card)}
    </span>
    """
  end

  def family_mark(assigns) do
    ~H"""
    <.illustration
      src={@card.image_path}
      alt={"Ilustração da família #{@card.title}"}
      class="size-[54px] shrink-0 rounded-lg"
    />
    """
  end

  defp family_mark_label(%{code: code}) when is_binary(code) and code != "", do: code
  defp family_mark_label(%{title: title}), do: title |> String.first() |> String.upcase()

  # O verde das onze ilustrações vai de #4b513f a #545d45. As famílias que nunca
  # foram desenhadas usam a média, para o mosaico ler como um conjunto só em vez
  # de metade desenho e metade buraco.
  @undrawn_ground "#4e5742"

  @doc """
  Uma família no mosaico: a ilustração é a superfície e o nome sobe nela.

  O nome fica sobre um degradê do próprio verde da ilustração, e não sobre uma
  tarja preta: a sobra já é aquele verde, então o texto parece pousado no chão
  onde os gatos dançam. Branco sobre esses verdes dá de 6,8 a 8,2:1.

  Família sem desenho recebe o mesmo chão verde com a sigla grande, que é como
  o passo é chamado em aula. Assim toda peça do mosaico tem o mesmo peso.
  """
  attr :card, :map, required: true
  attr :sizes, :string, required: true

  def family_tile(assigns) do
    assigns = assign(assigns, :ground, family_ground(assigns.card))

    ~H"""
    <button
      id={"collection-section-card-#{@card.id}"}
      phx-click="enter_section"
      phx-value-section_id={@card.id}
      class="group relative block w-full cursor-pointer overflow-hidden rounded-xl border-0 bg-transparent p-0 text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent-orange focus-visible:ring-offset-2 focus-visible:ring-offset-ink-100"
    >
      <.family_surface card={@card} sizes={@sizes} />
      <%!-- O degradê é do verde da própria ilustração, não uma tarja preta: a
           sobra da moldura já é aquele verde, então o nome parece pousado no
           chão onde os gatos dançam em vez de colado por cima. --%>
      <div
        class="pointer-events-none absolute inset-x-0 bottom-0 flex flex-col justify-end p-3 pt-10 sm:p-3.5 sm:pt-12"
        style={"background-image: linear-gradient(to top, #{@ground} 12%, #{@ground}d9 45%, transparent 100%)"}
      >
        <div class="brand-display is-title text-[15px] leading-tight text-white sm:text-[17px]">
          {@card.title}
        </div>
        <div class="mt-0.5 font-sans text-[11px] tabular-nums text-white/70">
          {@card.step_count} passos
        </div>
      </div>
    </button>
    """
  end

  defp family_ground(%{image_path: nil}), do: @undrawn_ground

  defp family_ground(%{image_path: path}) do
    case Illustration.source(path) do
      %{background: background} -> background
      nil -> @undrawn_ground
    end
  end

  defp family_surface(%{card: %{image_path: nil}} = assigns) do
    assigns = assign(assigns, :ground, @undrawn_ground)

    ~H"""
    <div
      class="flex aspect-square items-center justify-center"
      style={"background-color: #{@ground}"}
    >
      <span class="brand-display is-title text-[36px] leading-none text-white/45 sm:text-[44px]">
        {family_mark_label(@card)}
      </span>
    </div>
    """
  end

  defp family_surface(assigns) do
    ~H"""
    <.illustration
      src={@card.image_path}
      alt={"Ilustração da família #{@card.title}"}
      sizes={@sizes}
      class="aspect-square w-full transition-transform duration-300 group-hover:scale-[1.03]"
    />
    """
  end

  @doc """
  One step inside a family: the code that names it, and what you know about it.

  The card this replaced carried five badges in four accent colours, which made
  every step look like it was announcing an emergency. Only one of those states
  is about the person rather than about the step, so only that one keeps a
  colour: green means you already know it. The rest are the same quiet grey.
  """
  attr :step, :map, required: true
  attr :deep_linked, :boolean, default: false
  attr :steps_with_links, :any, default: %MapSet{}
  attr :steps_seen_in_class, :any, default: %MapSet{}
  attr :learned_step_ids, :any, default: %MapSet{}

  def step_row(assigns) do
    ~H"""
    <button
      id={"collection-step-#{@step.code}"}
      data-deep-linked={to_string(@deep_linked)}
      phx-click="open_step"
      phx-value-code={@step.code}
      class={[
        "group flex min-h-11 w-full cursor-pointer items-center gap-3 border-0 border-b border-ink-300/45",
        "py-2.5 pr-1 text-left transition-colors",
        @deep_linked && "border-l-2 border-l-accent-orange bg-accent-orange/5 pl-2",
        !@deep_linked && "bg-transparent pl-0"
      ]}
    >
      <code class="w-[52px] shrink-0 font-mono text-[11px] font-bold tracking-wide text-ink-500">
        {@step.code}
      </code>
      <span class="min-w-0 flex-1 truncate font-serif text-[15px] text-ink-900 transition-colors group-hover:text-accent-orange">
        {@step.name}
      </span>
      <span class="flex shrink-0 items-center gap-2 text-ink-400">
        <span
          :if={MapSet.member?(@steps_with_links, @step.id)}
          role="img"
          title="Tem vídeo"
          aria-label="Tem vídeo"
        >
          <.icon name="hero-play" class="size-3.5" />
        </span>
        <span
          :if={MapSet.member?(@steps_seen_in_class, @step.id)}
          role="img"
          title="Você viu este passo em aula"
          aria-label="Você viu este passo em aula"
        >
          <.icon name="hero-eye" class="size-3.5" />
        </span>
        <span
          :if={MapSet.member?(@learned_step_ids, @step.id)}
          role="img"
          title="Você já sabe este passo"
          aria-label="Você já sabe este passo"
          class="text-accent-green"
        >
          <.icon name="hero-check-circle-solid" class="size-4" />
        </span>
        <span
          :if={(@step.like_count || 0) > 0}
          class="inline-flex items-center gap-1 font-sans text-[11px] tabular-nums text-ink-500"
        >
          <.icon name="hero-heart-solid" class="size-3" />{@step.like_count}
        </span>
      </span>
    </button>
    """
  end

  attr :step, :map, required: true
  attr :current_user_id, :string, default: nil
  attr :steps_with_links, :any, default: %MapSet{}
  attr :steps_seen_in_class, :any, default: %MapSet{}
  attr :learned_step_ids, :any, default: %MapSet{}
  attr :step_likes, :map, default: %{liked_ids: %MapSet{}, counts: %{}}

  def step_item(assigns) do
    assigns =
      assign(assigns,
        has_links: MapSet.member?(assigns.steps_with_links, assigns.step.id),
        seen_in_class: MapSet.member?(assigns.steps_seen_in_class, assigns.step.id),
        learned: MapSet.member?(assigns.learned_step_ids, assigns.step.id),
        is_mine:
          assigns.step.suggested_by_id != nil and
            assigns.step.suggested_by_id == assigns.current_user_id
      )

    ~H"""
    <div class={[
      "border-b border-ink-200/40 rounded-md mb-0.5",
      @is_mine && "bg-accent-pink-bg",
      !@is_mine && "bg-transparent"
    ]}>
      <div
        id={"collection-step-list-#{@step.code}"}
        phx-click="open_step"
        phx-value-code={@step.code}
        class="flex gap-3.5 p-3 cursor-pointer"
      >
        <img
          :if={@step.image_path}
          src={"/#{@step.image_path}"}
          alt={@step.code}
          loading="lazy"
          class="w-[72px] h-[72px] object-cover rounded flex-shrink-0 border border-ink-300/60"
          style="filter: sepia(20%);"
        />
        <div class="flex-1 min-w-0">
          <div class="flex items-baseline gap-2.5 flex-wrap">
            <code class="font-mono text-xs font-bold text-ink-700 bg-gold-600/10 py-0.5 px-1.5 rounded-sm tracking-wide border border-gold-600/20">
              {@step.code}
            </code>
            <span class="text-sm text-ink-800 font-serif leading-normal">
              {@step.name}
            </span>
            <.link
              :if={@step.suggested_by_id}
              navigate={
                ~p"/users/#{if @step.suggested_by, do: @step.suggested_by.username, else: "#"}"
              }
              class="no-underline"
            >
              <span class={[
                "text-[10px] py-px px-1.5 rounded-full italic border",
                @step.approved && "border-accent-green/30 bg-accent-green/10 text-accent-green",
                !@step.approved && "border-accent-purple/30 bg-accent-purple/10 text-accent-purple"
              ]}>
                <%= if @step.approved do %>
                  ✓ @{if @step.suggested_by, do: @step.suggested_by.username, else: "?"}
                <% else %>
                  Sugestão de @{if @step.suggested_by, do: @step.suggested_by.username, else: "?"}
                <% end %>
              </span>
            </.link>
          </div>
          <p :if={@step.note} class="text-xs text-ink-600 mt-1 font-serif italic leading-relaxed">
            {String.slice(@step.note, 0, 120)}{if String.length(@step.note) > 120, do: "…"}
          </p>
        </div>
        <div class="flex flex-col items-center gap-1 flex-shrink-0">
          <span
            :if={@step.suggested_by_id}
            title="Contribuição da comunidade"
            class="flex items-center justify-center w-5 h-5 rounded-full bg-accent-purple/10 text-accent-purple"
          >
            <.icon name="hero-user" class="w-3 h-3" />
          </span>
          <span
            :if={@has_links}
            title="Tem vídeo/link"
            class="flex items-center justify-center w-5 h-5 rounded-full bg-accent-orange/10 text-accent-orange"
          >
            <.icon name="hero-play" class="w-3 h-3" />
          </span>
          <span
            :if={@seen_in_class}
            title="Você viu este passo em aula"
            class="flex items-center justify-center w-5 h-5 rounded-full bg-gold-500/15 text-gold-700"
          >
            <.icon name="hero-eye" class="w-3 h-3" />
          </span>
          <span
            :if={@learned}
            title="Você já sabe este passo"
            class="flex items-center justify-center w-5 h-5 rounded-full bg-accent-green/10 text-accent-green"
          >
            <.icon name="hero-check-circle-solid" class="w-3 h-3" />
          </span>
          <button
            phx-click="toggle_step_like"
            phx-value-id={@step.id}
            class="flex items-center gap-0.5 p-0.5"
            title={
              if MapSet.member?(@step_likes.liked_ids, @step.id),
                do: "Remover curtida",
                else: "Curtir"
            }
          >
            <.icon
              name={
                if MapSet.member?(@step_likes.liked_ids, @step.id),
                  do: "hero-heart-solid",
                  else: "hero-heart"
              }
              class={[
                "w-4 h-4",
                MapSet.member?(@step_likes.liked_ids, @step.id) && "text-accent-red",
                !MapSet.member?(@step_likes.liked_ids, @step.id) &&
                  "text-ink-300 hover:text-accent-red/60"
              ]}
            />
            <span class="text-[10px] tabular-nums text-ink-400">
              {Map.get(@step_likes.counts, @step.id, 0)}
            </span>
          </button>
        </div>
      </div>
    </div>
    """
  end
end
