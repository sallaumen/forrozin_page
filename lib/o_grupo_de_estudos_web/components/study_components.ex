defmodule OGrupoDeEstudosWeb.StudyComponents do
  @moduledoc """
  Shared function components of the Study area (/study and /study/shared/:id).

  It centralizes the blocks that repeat across "Meu estudo", "Meus professores",
  "Meus alunos" and the shared diary: section header, tabs, diary card (today's
  note), note history, step chips, person and stat cards, consistency and empty
  states.

  Everything is presentational: the events (`save`, `search`, `add`, `remove`, ...)
  arrive as attributes, so each LiveView reuses the same markup passing its own
  handlers (the same pattern as `UI.GoalsBoard`).
  """

  use OGrupoDeEstudosWeb, :html

  import OGrupoDeEstudosWeb.UI.StepSearch

  import OGrupoDeEstudosWeb.UI.UserAvatar

  @weekday_labels {"S", "T", "Q", "Q", "S", "S", "D"}

  attr :active, :string, required: true, values: ~w(personal teachers students workshops)
  attr :is_teacher, :boolean, default: false
  attr :pending_count, :integer, default: 0
  attr :lesson_count, :integer, default: 0

  @doc """
  The four ways into the study area, on one strip that fits a phone.

  The strip used to be 484px of pills-inside-a-pill on a 375px screen, which
  left Workshops outside the window behind a scrollbar nobody reads. "Meus" was
  doing no work in three of the four labels: the page is already yours.
  """
  def study_tabs(assigns) do
    ~H"""
    <%!-- O topo mede 56px para quem estuda e 76px para quem administra, porque o
    menu de admin faz a linha quebrar: um deslocamento fixo escondia até 28px da
    tira atrás dele. O próprio topo publica a altura em --top-nav-h. --%>
    <div
      class="sticky z-30 border-b border-ink-300/50 bg-ink-100/95 backdrop-blur-sm"
      style="top: var(--top-nav-h, 56px)"
    >
      <%!-- overflow-x-auto continua como rede de proteção: com nome de aba
      traduzido ou fonte maior, a tira rola em vez de cortar. --%>
      <div class="mx-auto max-w-[1500px] overflow-x-auto px-2 sm:px-6 lg:px-8">
        <div role="tablist" class="flex items-stretch gap-0.5 sm:gap-1">
          <.tab_link tab="personal" active={@active} label="Meu estudo" />
          <.tab_link tab="teachers" active={@active} label="Professores">
            <.tab_count count={@lesson_count} />
          </.tab_link>
          <.tab_link :if={@is_teacher} tab="students" active={@active} label="Alunos">
            <.tab_count count={@pending_count} />
          </.tab_link>
          <.tab_link tab="workshops" active={@active} label="Workshops" />
        </div>
      </div>
    </div>
    """
  end

  attr :count, :integer, required: true

  defp tab_count(assigns) do
    ~H"""
    <span
      :if={@count > 0}
      class="ml-1.5 inline-flex min-w-[17px] items-center justify-center rounded-full bg-accent-red px-1 py-0.5 font-sans text-[10px] font-bold leading-none text-white"
    >
      {@count}
    </span>
    """
  end

  # No celular as quatro abas dividem a largura em partes iguais: cabem todas,
  # e some a pergunta "tem mais coisa para a direita?". No desktop cada uma volta
  # à largura do próprio texto. O ativo é dito por um fio embaixo, não por uma
  # pílula clara dentro de uma pílula escura, que gastava largura só para existir.
  defp tab_class(active?) do
    [
      "inline-flex min-h-11 flex-1 cursor-pointer items-center justify-center whitespace-nowrap",
      "border-0 border-b-2 bg-transparent px-1 font-serif text-[12px] font-semibold tracking-tight",
      "no-underline transition-colors sm:flex-none sm:px-3.5 sm:text-[13px]",
      active? && "border-b-accent-orange text-accent-orange",
      !active? && "border-b-transparent text-ink-500 hover:text-ink-800"
    ]
  end

  # One tab of the strip, as an address rather than as local state. A tab used to
  # be an assign flipped by a click, so the browser was handed no history entry
  # and the back gesture left the site instead of stepping back one tab. It also
  # meant that going into a workshop and coming back landed on the diary, since
  # that is a remount and a remount keeps only what the address carries.
  attr :tab, :string, required: true, values: ~w(personal teachers students workshops)
  attr :active, :string, required: true
  attr :label, :string, required: true
  slot :inner_block

  defp tab_link(assigns) do
    assigns = assign(assigns, :nav, tab_nav(assigns.active, assigns.tab))

    ~H"""
    <.link
      {@nav}
      role="tab"
      aria-selected={to_string(@tab == @active)}
      class={tab_class(@tab == @active)}
    >
      {@label}{render_slot(@inner_block)}
    </.link>
    """
  end

  # Workshops is a LiveView of its own, so crossing that border is a navigate.
  # Between the three tabs of /study it is a patch, which keeps the dashboard
  # already loaded instead of running every query again.
  defp tab_nav(_active, "workshops"), do: %{navigate: ~p"/study/workshops"}
  defp tab_nav("workshops", tab), do: %{navigate: study_tab_path(tab)}
  defp tab_nav(_inside_study, tab), do: %{patch: study_tab_path(tab)}

  defp study_tab_path("personal"), do: ~p"/study"
  defp study_tab_path(tab), do: ~p"/study?tab=#{tab}"

  attr :title, :string, required: true
  attr :description, :string, default: nil
  slot :action

  @doc """
  The head of a study section.

  The eyebrow above the title used to say the title again in caps ("VOCÊ ENSINA"
  over "Meus alunos"), each tab in a colour of its own. The title says it once,
  in the display face the workshop pages already use.
  """
  def section_intro(assigns) do
    ~H"""
    <header class="mb-5 flex flex-wrap items-end justify-between gap-x-4 gap-y-3">
      <div class="min-w-0 flex-1 basis-[16rem]">
        <h1 class="brand-display is-title m-0 text-[26px] font-semibold leading-tight tracking-tight text-ink-900 md:text-[30px]">
          {@title}
        </h1>
        <p
          :if={@description}
          class="mt-2 max-w-[58ch] font-sans text-[13px] leading-relaxed text-ink-500"
        >
          {@description}
        </p>
      </div>
      <div :if={@action != []} class="flex shrink-0 flex-wrap items-center gap-2">
        {render_slot(@action)}
      </div>
    </header>
    """
  end

  attr :stats, :list, required: true

  @doc """
  Counts of a section, read as a sentence.

  Three numbers in three bordered boxes gave each one the weight of a decision;
  they are context, not choices, and one line of text carries them.
  """
  def stat_line(assigns) do
    ~H"""
    <p class="m-0 mb-5 flex flex-wrap items-baseline gap-x-4 gap-y-1 font-sans text-[13px] text-ink-500">
      <span :for={{value, label} <- @stats}>
        <b class="font-semibold text-ink-900">{value}</b> {label}
      </span>
    </p>
    """
  end

  attr :tone, :atom, default: :primary, values: [:primary, :ghost]
  attr :icon, :string, default: nil
  # Inside a form the button has to be submit, otherwise the click sends nothing.
  attr :type, :string, default: "button", values: ~w(button submit)
  attr :disabled, :boolean, default: false

  # `form` lets the button submit a form it is not nested inside (lesson composer).
  attr :rest, :global,
    include:
      ~w(phx-click phx-value-id phx-value-tab phx-value-link-id navigate href data-confirm phx-disable-with form)

  slot :inner_block, required: true

  def action_button(assigns) do
    ~H"""
    <button
      type={@type}
      disabled={@disabled}
      class={[
        "inline-flex min-h-11 items-center gap-1.5 rounded-full px-4 font-serif text-sm font-semibold no-underline transition-colors sm:min-h-9",
        @tone == :primary && "bg-accent-orange text-on-accent hover:bg-accent-orange/90",
        @tone == :ghost &&
          "border border-ink-300 bg-ink-50 text-ink-700 hover:border-ink-400 hover:text-ink-900",
        @disabled && "cursor-not-allowed opacity-50",
        !@disabled && "cursor-pointer"
      ]}
      {@rest}
    >
      <.icon :if={@icon} name={@icon} class="size-4" />
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :navigate, :string, required: true
  attr :tone, :atom, default: :primary, values: [:primary, :ghost, :subtle]
  attr :icon, :string, default: nil
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def action_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "inline-flex min-h-11 items-center gap-1.5 rounded-full px-3.5 font-serif text-[13px] font-semibold no-underline transition-colors sm:min-h-9",
        @tone == :primary && "bg-accent-orange text-on-accent hover:bg-accent-orange/90",
        @tone == :ghost &&
          "border border-ink-300 bg-ink-50 text-ink-700 hover:border-ink-400 hover:text-ink-900",
        @tone == :subtle && "text-accent-orange hover:text-accent-orange/80",
        @class
      ]}
    >
      <.icon :if={@icon} name={@icon} class="size-4" />
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :title, :string, default: nil
  attr :icon, :string, default: nil
  attr :class, :any, default: nil
  slot :inner_block, required: true

  # Bloco da coluna lateral: um fio separa um assunto do outro, do mesmo jeito
  # que na ficha do workshop. Três caixas empilhadas davam a cada widget o peso
  # de um cartão selecionável, e nenhum deles é.
  def sidebar_card(assigns) do
    ~H"""
    <section class={["border-t border-ink-200 pt-4 first:border-t-0 first:pt-0", @class]}>
      <h2
        :if={@title}
        class="brand-display is-title m-0 mb-3 flex items-center gap-1.5 text-[15px] font-semibold tracking-tight text-ink-800"
      >
        <.icon :if={@icon} name={@icon} class="size-4 text-gold-600" />
        {@title}
      </h2>
      {render_slot(@inner_block)}
    </section>
    """
  end

  attr :monthly_count, :integer, required: true
  attr :month_name, :string, required: true
  attr :week_weekdays, :any, required: true
  attr :today_weekday, :integer, required: true

  def consistency_card(assigns) do
    ~H"""
    <.sidebar_card title="Consistência" icon="hero-fire">
      <div class="flex items-baseline gap-1.5">
        <span class="font-serif text-3xl font-bold leading-none text-ink-900">{@monthly_count}</span>
        <span class="text-xs text-ink-500">
          {if @monthly_count == 1, do: "dia", else: "dias"} em {@month_name}
        </span>
      </div>
      <div class="mt-3 flex justify-between gap-1">
        <div :for={dow <- 1..7} class="flex flex-1 flex-col items-center gap-1">
          <div class={[
            "flex aspect-square w-full max-w-[28px] items-center justify-center rounded-md border text-[10px] font-bold transition-colors",
            MapSet.member?(@week_weekdays, dow) && "border-transparent bg-gold-500 text-on-accent",
            !MapSet.member?(@week_weekdays, dow) && dow == @today_weekday &&
              "border-accent-orange bg-accent-orange/10 text-accent-orange",
            !MapSet.member?(@week_weekdays, dow) && dow != @today_weekday &&
              "border-ink-200 bg-ink-100 text-ink-300"
          ]}>
            {weekday_label(dow)}
          </div>
        </div>
      </div>
      <p class="mt-3 text-[11px] leading-relaxed text-ink-500">
        A consistência é o que transforma prática em memória. Cada dia conta.
      </p>
    </.sidebar_card>
    """
  end

  attr :value, :any, required: true
  attr :label, :string, required: true
  attr :tone, :atom, default: :neutral, values: [:neutral, :success, :accent]
  attr :highlighted, :boolean, default: false

  def stat_card(assigns) do
    ~H"""
    <div class={[
      "rounded-2xl border p-3.5 text-center shadow-sm",
      @highlighted && "border-gold-500/40 bg-gold-500/[0.06]",
      !@highlighted && "border-ink-200 bg-ink-50"
    ]}>
      <div class={[
        "font-serif text-2xl font-bold leading-none",
        @tone == :neutral && "text-ink-900",
        @tone == :success && "text-accent-green",
        @tone == :accent && "text-accent-orange"
      ]}>
        {@value}
      </div>
      <div class="mt-1 text-[10px] uppercase tracking-wide text-ink-500">{@label}</div>
    </div>
    """
  end

  attr :step, :map, required: true
  attr :removable, :boolean, default: false
  attr :learned, :boolean, default: false
  attr :remove_event, :string, default: nil
  attr :remove_label, :string, default: "desta nota"
  attr :rest, :global, include: ~w(phx-value-id phx-value-note-id phx-value-step-id disabled)

  def step_pill(assigns) do
    ~H"""
    <%!-- Dois alvos separados quando dá para remover: abrir e tirar são gestos
    opostos, e um X dentro de um botão que também abre erra o dedo no celular.
    O passo em si sempre abre a folha: antes ele era texto morto, e quem lia a
    própria anotação não conseguia fazer nada com o que viu na aula. --%>
    <span
      :if={@removable}
      class={[
        "inline-flex items-center rounded-full border text-[11px] font-semibold",
        @learned && "border-accent-green/30 bg-accent-green/[0.10] text-accent-green",
        !@learned && "border-accent-orange/25 bg-accent-orange/[0.08] text-accent-orange"
      ]}
    >
      <button
        type="button"
        phx-click="open_step_sheet"
        phx-value-code={@step.code}
        class="inline-flex cursor-pointer items-center gap-1.5 rounded-l-full py-1 pl-2.5 pr-1 transition-colors hover:brightness-95"
      >
        <.icon :if={@learned} name="hero-check-circle-solid" class="size-3" />
        <code class="font-bold">{@step.code}</code>
        <span class="font-normal text-ink-600">{@step.name}</span>
      </button>
      <button
        type="button"
        phx-click={@remove_event}
        aria-label={"Tirar #{@step.code} #{@remove_label}"}
        class="group cursor-pointer rounded-r-full py-1 pl-1 pr-2.5 disabled:cursor-default disabled:opacity-70"
        {@rest}
      >
        <.icon name="hero-x-mark" class="size-3 opacity-60 group-hover:opacity-100" />
      </button>
    </span>

    <button
      :if={!@removable}
      type="button"
      phx-click="open_step_sheet"
      phx-value-code={@step.code}
      class={[
        "inline-flex cursor-pointer items-center gap-1.5 rounded-full border px-2.5 py-0.5 text-[10px] transition-colors hover:brightness-95",
        @learned && "border-accent-green/30 bg-accent-green/[0.12] text-accent-green",
        !@learned && "border-accent-orange/20 bg-accent-orange/10 text-accent-orange"
      ]}
    >
      <.icon :if={@learned} name="hero-check-circle-solid" class="size-2.5" />
      <code class="font-bold">{@step.code}</code>
      <span class="text-ink-600">{@step.name}</span>
    </button>
    """
  end

  attr :tab, :string, default: nil
  attr :draft_steps, :list, default: []
  attr :draft_name, :string, default: ""
  attr :search_term, :string, default: ""
  attr :step_matches, :list, default: []
  attr :mine, :list, default: []
  attr :cited_ids, :any, default: nil

  @doc """
  The sheet that builds or cites a sequence, opened from a study screen.

  Same shell as `step_sheet/1`, on purpose: the gesture of "a layer opens over
  what I was reading" is already learned here, and a second shape would make the
  two feel like different apps.
  """
  def sequence_sheet(assigns) do
    ~H"""
    <div
      :if={@tab}
      id="sequence-sheet"
      class="fixed inset-0 z-50 flex items-end justify-center bg-ink-900/40 p-0 sm:items-center sm:p-4"
      phx-window-keydown="close_sequence_sheet"
      phx-key="escape"
    >
      <%!-- Closing is `phx-click-away` on the panel, not `phx-click` on the
      backdrop: a click inside bubbles up to the backdrop, so the save button was
      closing the sheet and dropping the draft before the event reached the
      server. --%>
      <%!-- The panel scrolls, the page does not: on a short phone a mid-size
      draft plus open matches is taller than the screen, and without this the
      tabs slide up out of reach. The bottom padding clears the home bar. --%>
      <div
        class="max-h-[calc(100dvh-0.75rem)] w-full overflow-y-auto overscroll-contain rounded-t-2xl border border-ink-200 bg-ink-50 p-4 pb-[max(1rem,env(safe-area-inset-bottom))] shadow-lg sm:max-h-[85vh] sm:max-w-[24rem] sm:rounded-2xl"
        phx-click-away="close_sequence_sheet"
      >
        <div class="mx-auto mb-3 h-1 w-9 rounded-full bg-ink-200 sm:hidden"></div>

        <div class="mb-3 flex gap-1.5">
          <button
            :for={{value, label} <- [{"new", "Nova"}, {"mine", "Minhas sequências"}]}
            type="button"
            phx-click="sequence_sheet_tab"
            phx-value-tab={value}
            class={[
              "min-h-9 flex-1 rounded-full px-3 text-[12px] font-semibold transition",
              @tab == value && "bg-ink-900 text-ink-50",
              @tab != value && "border border-ink-200 text-ink-600 hover:border-gold-500"
            ]}
          >
            {label}
          </button>
        </div>

        <div :if={@tab == "new"}>
          <%!-- The track is the sequence: chip, arrow, chip. Holding a chip
          lifts a copy that follows the finger and trembles lightly, and the gap
          it left slides between the others, so the result is visible before
          letting go. --%>
          <p class="m-0 mb-1.5 text-[10px] font-semibold uppercase tracking-[0.13em] text-ink-500">
            A sequência
          </p>
          <div
            id="sequence-draft-track"
            phx-hook="DragReorder"
            data-reorder-event="sequence_draft_reorder"
            class="flex min-h-[52px] flex-wrap items-center gap-1.5 rounded-xl border border-dashed border-ink-300 bg-gold-500/[0.04] p-2"
          >
            <span
              :if={@draft_steps == []}
              class="px-1.5 font-serif text-[12.5px] italic text-ink-400"
            >
              Nenhum passo ainda. Busque abaixo.
            </span>
            <.sequence_draft_chip
              :for={{step, index} <- Enum.with_index(@draft_steps)}
              step={step}
              index={index}
              last={index == length(@draft_steps) - 1}
            />
          </div>

          <input
            type="text"
            name="step_search"
            value={@search_term}
            autocomplete="off"
            placeholder="Adicionar passo…"
            phx-keyup="sequence_search_step"
            phx-debounce="200"
            class="mt-3 min-h-10 w-full rounded-lg border border-ink-300 bg-ink-50 px-3 text-[13px] text-ink-900 placeholder:text-ink-400"
          />
          <div :if={@step_matches != []} class="mt-1.5 flex flex-wrap gap-1.5">
            <button
              :for={match <- @step_matches}
              type="button"
              phx-click="sequence_draft_add"
              phx-value-code={match.code}
              class="inline-flex min-h-8 items-center gap-1.5 rounded-full border border-ink-300 px-3 text-[11px] font-semibold text-ink-700 transition hover:border-gold-500 hover:bg-gold-500/[0.08]"
            >
              <span class="font-bold text-gold-600">+</span>
              <code class="font-bold">{match.code}</code>
              <span class="font-medium text-ink-600">{match.name}</span>
            </button>
          </div>

          <input
            type="text"
            name="name"
            value={@draft_name}
            placeholder="Nome da sequência"
            phx-keyup="sequence_draft_name"
            phx-debounce="200"
            class="mt-2.5 min-h-10 w-full rounded-lg border border-ink-300 bg-ink-50 px-3 text-[13px] text-ink-900 placeholder:text-ink-400"
          />
          <%!-- Botão que dispara o evento, e não submit de formulário: o form
          precisaria de `display: contents` para não quebrar o empilhamento, e
          nessa combinação o clique deixa de submeter. --%>
          <button
            type="button"
            phx-click="save_sequence"
            disabled={length(@draft_steps) < 2 or String.trim(@draft_name) == ""}
            class="mt-3 min-h-11 w-full rounded-full bg-ink-900 text-[12.5px] font-semibold text-ink-50 transition disabled:opacity-40"
          >
            Salvar e citar aqui
          </button>
        </div>

        <div :if={@tab == "mine"}>
          <p
            :if={@mine == []}
            class="m-0 py-6 text-center font-serif text-[13px] italic text-ink-400"
          >
            Você ainda não tem sequências salvas.
          </p>
          <ul :if={@mine != []} class="m-0 max-h-[46vh] list-none overflow-y-auto p-0">
            <li :for={sequence <- @mine} class="border-b border-ink-200 last:border-none">
              <button
                type="button"
                phx-click="cite_sequence"
                phx-value-id={sequence.id}
                disabled={cited?(@cited_ids, sequence.id)}
                class="flex w-full min-h-12 items-center gap-2.5 px-1 py-2.5 text-left transition hover:bg-gold-500/[0.07] disabled:opacity-45"
              >
                <span class="grid size-8 shrink-0 place-items-center rounded-lg bg-gold-500/15 text-[11px] font-bold text-gold-600">
                  →
                </span>
                <span class="min-w-0 flex-1">
                  <span class="block truncate text-[13px] font-semibold text-ink-900">
                    {sequence.name}
                  </span>
                  <span class="block text-[11px] text-ink-500">
                    {length(sequence.sequence_steps)} passos
                  </span>
                </span>
                <span :if={cited?(@cited_ids, sequence.id)} class="text-[11px] text-ink-500">
                  já citada
                </span>
              </button>
            </li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  defp cited?(nil, _id), do: false
  defp cited?(ids, id), do: MapSet.member?(ids, id)

  attr :step, :map, required: true
  attr :index, :integer, required: true
  attr :last, :boolean, default: false

  defp sequence_draft_chip(assigns) do
    ~H"""
    <span
      data-reorder-id={@index}
      tabindex="0"
      role="button"
      aria-label={"#{@step.name}, posição #{@index + 1}. Setas movem de posição."}
      class="inline-flex min-h-[34px] cursor-grab select-none items-center gap-1.5 rounded-full border border-gold-500/45 bg-gold-500/[0.12] py-0.5 pl-3 pr-1 text-[11.5px] font-semibold text-ink-800"
    >
      <span class="min-w-2 text-center text-[9px] font-bold tabular-nums text-gold-600">
        {@index + 1}
      </span>
      <code class="font-bold">{@step.code}</code>
      <span class="font-medium text-ink-600">{@step.name}</span>
      <%!-- The glyph stays small; the hit area is the finger-sized box around
      it, or removing on a phone takes three tries. --%>
      <span
        data-reorder-ignore
        phx-click="sequence_draft_remove"
        phx-value-index={@index}
        class="grid size-8 cursor-pointer place-items-center rounded-full text-[13px] leading-none text-ink-400 hover:bg-ink-200 hover:text-ink-700"
      >
        ×
      </span>
    </span>
    <span :if={!@last} class="select-none text-[12px] text-ink-400">→</span>
    """
  end

  attr :step, :map, default: nil
  attr :learned, :boolean, default: false

  @doc """
  Layer with the step and the learn gesture, opened from a chip in the note.

  A sheet, and not the whole step page, so the person does not lose sight of the
  note they were reading. Whoever wants the full step (connections, videos,
  conversation) has the link in the footer.
  """
  def step_sheet(assigns) do
    ~H"""
    <div
      :if={@step}
      id="step-sheet"
      class="fixed inset-0 z-50 flex items-end justify-center bg-ink-900/40 p-0 sm:items-center sm:p-4"
      phx-click="close_step_sheet"
      phx-window-keydown="close_step_sheet"
      phx-key="escape"
    >
      <%!-- No celular é folha que sobe (o polegar alcança); no desktop vira um
      cartão compacto, porque abrir um modal de 26rem para um gesto de um
      clique pesa mais do que o gesto. O accent segue o estado: a folha é o
      chip aberto, e trocar de cor no meio do caminho quebraria a ligação
      entre o que se clicou e o que abriu. --%>
      <div
        class={[
          "w-full rounded-t-2xl border bg-ink-50 p-4 shadow-lg sm:max-w-[20rem] sm:rounded-2xl",
          @learned && "border-accent-green/30",
          !@learned && "border-ink-200"
        ]}
        phx-click-away="close_step_sheet"
      >
        <div class="flex items-start gap-2.5">
          <code class={[
            "shrink-0 rounded-md px-1.5 py-0.5 text-[12px] font-bold",
            @learned && "bg-accent-green/15 text-accent-green",
            !@learned && "bg-accent-orange/15 text-accent-orange"
          ]}>
            {@step.code}
          </code>
          <div class="min-w-0 flex-1">
            <p class="m-0 font-serif text-[15px] font-bold leading-tight text-ink-900">
              {@step.name}
            </p>
            <p :if={@step.note} class="m-0 mt-0.5 line-clamp-2 text-[12px] leading-snug text-ink-500">
              {@step.note}
            </p>
          </div>
        </div>

        <button
          type="button"
          phx-click="toggle_step_learned"
          phx-value-code={@step.code}
          aria-pressed={to_string(@learned)}
          class={[
            "mt-3 flex w-full cursor-pointer items-center justify-center gap-1.5 rounded-full border px-4 py-2 font-serif text-[13px] font-semibold transition-colors",
            @learned && "border-accent-green/40 bg-accent-green/12 text-accent-green",
            !@learned && "border-ink-300 bg-ink-100 text-ink-700 hover:border-ink-400"
          ]}
        >
          <.icon
            name={if @learned, do: "hero-check-circle-solid", else: "hero-academic-cap"}
            class="size-4"
          />
          {if @learned, do: "Você já sabe este passo", else: "Já sei este passo"}
        </button>

        <div class="mt-2 flex items-center justify-between text-[12px]">
          <.link
            navigate={~p"/steps/#{@step.code}"}
            class="font-semibold text-accent-orange no-underline"
          >
            Ver o passo completo →
          </.link>
          <button
            type="button"
            phx-click="close_step_sheet"
            class="cursor-pointer border-0 bg-transparent p-0 text-ink-500 underline"
          >
            fechar
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, default: "study-diary"
  attr :eyebrow, :string, default: nil
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :content, :string, default: ""
  attr :placeholder, :string, default: "O que você praticou hoje?"
  attr :form_as, :atom, required: true
  attr :related_steps, :list, default: []
  attr :suggestions, :list, default: []
  attr :disabled, :boolean, default: false
  attr :rows, :integer, default: 4
  attr :save_event, :string, required: true
  attr :search_event, :string, required: true
  attr :add_event, :string, required: true
  attr :remove_event, :string, required: true
  slot :meta
  slot :footer

  attr :learned_codes, :any, default: nil

  def diary_card(assigns) do
    ~H"""
    <section id={@id} class="rounded-xl border border-ink-200 bg-ink-50 p-4 sm:p-5">
      <div class="mb-3 flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1">
        <div class="min-w-0">
          <h2 class="brand-display is-title m-0 text-[18px] font-semibold leading-snug tracking-tight text-ink-900">
            {@title}
          </h2>
          <p :if={@description} class="mt-1 text-xs leading-relaxed text-ink-500">{@description}</p>
        </div>
        <div :if={@meta != []} class="shrink-0 text-right">{render_slot(@meta)}</div>
      </div>

      <.form
        for={to_form(%{"content" => @content}, as: @form_as)}
        id={"#{@id}-form"}
        phx-change={@save_event}
        phx-submit={@save_event}
      >
        <textarea
          name={"#{@form_as}[content]"}
          rows={@rows}
          placeholder={@placeholder}
          disabled={@disabled}
          phx-debounce="800"
          class="w-full resize-y rounded-xl border border-ink-200 bg-ink-100/40 px-4 py-3 font-serif text-sm leading-7 text-ink-900 outline-none transition-colors focus:border-accent-orange/40 focus:ring-1 focus:ring-accent-orange/20 disabled:opacity-70"
        >{@content}</textarea>
      </.form>

      <div class="mt-3">
        <div :if={@related_steps != []} class="mb-2 flex flex-wrap gap-1.5">
          <.step_pill
            :for={step <- @related_steps}
            step={step}
            learned={knows?(@learned_codes, step)}
            removable={!@disabled}
            remove_event={@remove_event}
            phx-value-id={step.id}
            disabled={@disabled}
          />
        </div>
        <.step_search
          :if={!@disabled}
          id={"#{@id}-step-search"}
          suggestions={@suggestions}
          placeholder="+ Vincular passo ao estudo de hoje"
          search_event={@search_event}
          add_event={@add_event}
        />
      </div>

      <div :if={@footer != []} class="mt-4 border-t border-ink-200 pt-3">
        {render_slot(@footer)}
      </div>
    </section>
    """
  end

  attr :title, :string, default: "Notas anteriores"
  attr :notes, :list, required: true
  attr :count_label, :string, default: nil
  attr :expanded_ids, :any, default: %MapSet{}
  attr :editing_note_id, :string, default: nil
  attr :suggestions, :list, default: []
  attr :editable, :boolean, default: true
  attr :toggle_expand_event, :string, default: "toggle_note_expansion"
  attr :edit_steps_event, :string, default: "edit_history_steps"
  attr :search_step_event, :string, default: "search_history_step"
  attr :add_step_event, :string, default: "add_history_step"
  attr :remove_step_event, :string, default: "remove_history_step"
  slot :empty

  attr :learned_codes, :any, default: nil

  def note_history(assigns) do
    ~H"""
    <section class="mt-2 border-t border-ink-200 pt-5">
      <div class="mb-3 flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1">
        <h2 class="brand-display is-title m-0 text-[16px] font-semibold tracking-tight text-ink-800">
          {@title}
        </h2>
        <span :if={@count_label} class="font-sans text-[11.5px] text-ink-500">{@count_label}</span>
      </div>

      <div :if={@notes == []}>
        {render_slot(@empty)}
      </div>

      <div :if={@notes != []} class="space-y-2">
        <.history_note
          :for={note <- @notes}
          note={note}
          learned_codes={@learned_codes}
          expanded={MapSet.member?(@expanded_ids, note.id)}
          editing={@editing_note_id == note.id}
          editable={@editable}
          suggestions={@suggestions}
          toggle_expand_event={@toggle_expand_event}
          edit_steps_event={@edit_steps_event}
          search_step_event={@search_step_event}
          add_step_event={@add_step_event}
          remove_step_event={@remove_step_event}
        />
      </div>
    </section>
    """
  end

  attr :note, :map, required: true
  attr :expanded, :boolean, default: false
  attr :editing, :boolean, default: false
  attr :editable, :boolean, default: true
  attr :suggestions, :list, default: []
  attr :toggle_expand_event, :string, required: true
  attr :edit_steps_event, :string, required: true
  attr :search_step_event, :string, required: true
  attr :add_step_event, :string, required: true
  attr :remove_step_event, :string, required: true

  attr :learned_codes, :any, default: nil

  defp history_note(assigns) do
    assigns = assign(assigns, :long?, String.length(assigns.note.content || "") > 150)

    ~H"""
    <article class="rounded-xl border border-ink-200 bg-ink-100/40 px-3.5 py-3">
      <div class="flex flex-wrap items-center gap-1.5">
        <span class="text-[11px] font-bold text-ink-700">
          {OGrupoDeEstudos.Brazil.format_date(@note.note_date)}
        </span>
      </div>

      <div :if={@note.related_steps != []} class="mt-1.5 flex flex-wrap gap-1">
        <.step_pill
          :for={step <- @note.related_steps}
          step={step}
          learned={knows?(@learned_codes, step)}
        />
      </div>

      <%= if @long? do %>
        <p class={[
          "mt-1.5 whitespace-pre-line text-xs leading-6 text-ink-700",
          !@expanded && "line-clamp-2"
        ]}>
          {@note.content}
        </p>
        <button
          type="button"
          phx-click={@toggle_expand_event}
          phx-value-id={@note.id}
          class="mt-0.5 text-[11px] font-semibold text-accent-orange hover:text-accent-orange/80"
        >
          {if @expanded, do: "ver menos", else: "ver mais"}
        </button>
      <% else %>
        <p class="mt-1.5 whitespace-pre-line text-xs leading-6 text-ink-700">{@note.content}</p>
      <% end %>

      <button
        :if={@editable}
        type="button"
        phx-click={@edit_steps_event}
        phx-value-note-id={@note.id}
        class="mt-1.5 text-[10px] font-semibold text-accent-orange/90 hover:text-accent-orange"
      >
        {if @editing, do: "fechar", else: "editar passos"}
      </button>

      <div :if={@editing} class="mt-2 rounded-lg border border-ink-200/60 bg-ink-100/60 p-2.5">
        <div :if={@note.related_steps != []} class="mb-2 flex flex-wrap gap-1">
          <.step_pill
            :for={step <- @note.related_steps}
            step={step}
            learned={knows?(@learned_codes, step)}
            removable
            remove_event={@remove_step_event}
            phx-value-note-id={@note.id}
            phx-value-step-id={step.id}
          />
        </div>
        <.step_search
          id={"history-step-search-#{@note.id}"}
          suggestions={@suggestions}
          search_event={@search_step_event}
          add_event={@add_step_event}
          phx-value-note-id={@note.id}
        />
      </div>
    </article>
    """
  end

  attr :user, :map, required: true
  # Quem é professor e quem é aluno já está dito pela aba onde a linha aparece:
  # a etiqueta em caixa alta ao lado do nome repetia isso e roubava a largura.
  attr :status_label, :string, default: nil
  attr :href, :string, default: nil
  slot :actions
  slot :footer

  @doc """
  One person of the study area: who they are, and the way in.

  On a phone the name used to get 52px of the 130px it needed, because it shared
  a row with a badge and two buttons that never shrink: "Marina Kienteca" read
  "Mar…". Here the buttons wrap to their own row below 640px, so the name always
  has the width of the card, and the row is a hairline instead of a card with a
  coloured rail.
  """
  def person_card(assigns) do
    ~H"""
    <div class="border-t border-ink-200 py-3.5 first:border-t-0">
      <div class="flex flex-wrap items-center gap-x-3 gap-y-2.5 sm:flex-nowrap">
        <.maybe_user_link
          href={@href}
          class="flex min-w-0 flex-1 basis-full items-center gap-3 no-underline sm:basis-auto"
        >
          <.user_avatar user={@user} size={:lg} />
          <div class="min-w-0 flex-1">
            <p class="m-0 font-serif text-[15px] font-bold leading-snug text-ink-900">
              {@user.name || @user.username}
            </p>
            <p class="m-0 mt-0.5 font-sans text-[11.5px] text-ink-500">
              @{@user.username}<span :if={@status_label}> · {@status_label}</span>
            </p>
          </div>
        </.maybe_user_link>
        <div :if={@actions != []} class="flex shrink-0 items-center gap-2">
          {render_slot(@actions)}
        </div>
      </div>
      <div :if={@footer != []} class="mt-2.5">{render_slot(@footer)}</div>
    </div>
    """
  end

  attr :href, :string, default: nil
  attr :class, :any, default: nil
  slot :inner_block, required: true

  defp maybe_user_link(assigns) do
    ~H"""
    <.link :if={@href} navigate={@href} class={@class}>{render_slot(@inner_block)}</.link>
    <div :if={!@href} class={@class}>{render_slot(@inner_block)}</div>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, default: nil
  slot :action

  # Ainda não ter nada é uma frase, não um anúncio emoldurado: a caixa tracejada
  # com ícone vestia uma ausência como se fosse mais um item da lista.
  def empty_state(assigns) do
    ~H"""
    <div class="border-t border-ink-200 py-8">
      <p class="brand-display is-title m-0 text-[16px] font-semibold tracking-tight text-ink-800">
        {@title}
      </p>
      <p
        :if={@description}
        class="m-0 mt-1.5 max-w-[52ch] font-sans text-[13px] leading-relaxed text-ink-500"
      >
        {@description}
      </p>
      <div :if={@action != []} class="mt-4">{render_slot(@action)}</div>
    </div>
    """
  end

  defp weekday_label(dow), do: elem(@weekday_labels, dow - 1)

  # `nil` means the screen did not load the state: better to show everything as
  # not-yet-known than to crash. A MapSet of codes is what the screens build,
  # because a chip always has the code at hand.
  defp knows?(nil, _step), do: false
  defp knows?(codes, %{code: code}), do: MapSet.member?(codes, code)
  defp knows?(_codes, _step), do: false
end
