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

  import OGrupoDeEstudosWeb.UI.UserAvatar

  @weekday_labels {"S", "T", "Q", "Q", "S", "S", "D"}

  attr :active, :string, required: true, values: ~w(personal teachers students workshops)
  attr :is_teacher, :boolean, default: false
  attr :pending_count, :integer, default: 0
  attr :lesson_count, :integer, default: 0

  def study_tabs(assigns) do
    ~H"""
    <div class="sticky top-[48px] md:top-[52px] z-30 border-b border-ink-300/40 bg-ink-100/95 backdrop-blur-sm">
      <%!-- overflow-x-auto: com quatro abas o tablist estoura a largura no celular --%>
      <div class="mx-auto max-w-[1500px] overflow-x-auto px-4 py-2.5 sm:px-6 lg:px-8">
        <div
          role="tablist"
          class="inline-flex items-center gap-0.5 rounded-full border border-ink-200 bg-ink-200/60 p-1"
        >
          <.tab_link
            :if={@active == "workshops"}
            navigate="/study"
            label="Meu estudo"
          />
          <.tab_button
            :if={@active != "workshops"}
            tab="personal"
            active={@active}
            label="Meu estudo"
          />
          <.tab_link
            :if={@active == "workshops"}
            navigate="/study"
            label="Meus professores"
          />
          <.tab_button
            :if={@active != "workshops"}
            tab="teachers"
            active={@active}
            label="Meus professores"
          >
            <span
              :if={@lesson_count > 0}
              class="ml-1.5 inline-flex min-w-[18px] items-center justify-center rounded-full bg-accent-red px-1.5 py-0.5 text-[10px] font-bold leading-none text-white"
            >
              {@lesson_count}
            </span>
          </.tab_button>
          <.tab_link
            :if={@active == "workshops" && @is_teacher}
            navigate="/study"
            label="Meus alunos"
          />
          <.tab_button
            :if={@active != "workshops" && @is_teacher}
            tab="students"
            active={@active}
            label="Meus alunos"
          >
            <span
              :if={@pending_count > 0}
              class="ml-1.5 inline-flex min-w-[18px] items-center justify-center rounded-full bg-accent-red px-1.5 py-0.5 text-[10px] font-bold leading-none text-white"
            >
              {@pending_count}
            </span>
          </.tab_button>
          <.tab_link
            navigate="/study/workshops"
            label="Workshops"
            active={@active == "workshops"}
          />
        </div>
      </div>
    </div>
    """
  end

  # The workshops tab lives in its own LiveView (deep link and a real URL), so
  # it navigates instead of flipping local state.
  attr :navigate, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false

  defp tab_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      role="tab"
      aria-selected={to_string(@active)}
      class={[
        "inline-flex items-center whitespace-nowrap rounded-full px-3 py-1.5 font-serif text-xs font-semibold tracking-tight no-underline transition-colors sm:px-3.5 sm:text-[13px]",
        @active && "bg-ink-50 text-accent-orange shadow-sm",
        !@active && "bg-transparent text-ink-500 hover:text-ink-800"
      ]}
    >
      {@label}
    </.link>
    """
  end

  attr :tab, :string, required: true
  attr :active, :string, required: true
  attr :label, :string, required: true
  slot :inner_block

  defp tab_button(assigns) do
    ~H"""
    <button
      type="button"
      role="tab"
      aria-selected={to_string(@tab == @active)}
      phx-click="switch_study_tab"
      phx-value-tab={@tab}
      class={[
        "inline-flex items-center whitespace-nowrap rounded-full px-3 py-1.5 font-serif text-xs font-semibold tracking-tight transition-colors sm:px-3.5 sm:text-[13px]",
        @tab == @active && "bg-ink-50 text-accent-orange shadow-sm",
        @tab != @active && "bg-transparent text-ink-500 hover:text-ink-800"
      ]}
    >
      {@label}{render_slot(@inner_block)}
    </button>
    """
  end

  attr :eyebrow, :string, required: true
  attr :eyebrow_icon, :string, default: nil
  attr :tone, :atom, default: :orange, values: [:orange, :purple, :gold]
  attr :title, :string, required: true
  attr :description, :string, default: nil
  slot :action

  def section_intro(assigns) do
    ~H"""
    <header class="mb-5 flex flex-wrap items-end justify-between gap-3">
      <div class="min-w-0">
        <p class={[
          "mb-1.5 flex items-center gap-1.5 text-[11px] font-bold uppercase tracking-[0.18em]",
          @tone == :orange && "text-accent-orange",
          @tone == :purple && "text-accent-purple",
          @tone == :gold && "text-gold-600"
        ]}>
          <.icon :if={@eyebrow_icon} name={@eyebrow_icon} class="size-3.5" />
          {@eyebrow}
        </p>
        <h1 class="m-0 font-serif text-2xl font-bold leading-tight tracking-tight text-ink-900 md:text-3xl">
          {@title}
        </h1>
        <p :if={@description} class="mt-1.5 max-w-prose text-sm leading-relaxed text-ink-500">
          {@description}
        </p>
      </div>
      <div :if={@action != []} class="flex shrink-0 items-center gap-2">
        {render_slot(@action)}
      </div>
    </header>
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
        "inline-flex items-center gap-1.5 rounded-full px-4 py-2 font-serif text-sm font-semibold no-underline transition-colors",
        @tone == :primary && "bg-accent-orange text-white hover:bg-accent-orange/90",
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
        "inline-flex items-center gap-1.5 rounded-full px-3.5 py-1.5 font-serif text-[13px] font-semibold no-underline transition-colors",
        @tone == :primary && "bg-accent-orange text-white hover:bg-accent-orange/90",
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

  def sidebar_card(assigns) do
    ~H"""
    <section class={["rounded-2xl border border-ink-200 bg-ink-50 p-4 shadow-sm", @class]}>
      <h2
        :if={@title}
        class="m-0 mb-3 flex items-center gap-1.5 font-serif text-sm font-bold text-ink-900"
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
            MapSet.member?(@week_weekdays, dow) && "border-transparent bg-gold-500 text-white",
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
      <div
        class="w-full rounded-t-2xl border border-ink-200 bg-ink-50 p-4 shadow-lg sm:max-w-[24rem] sm:rounded-2xl"
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
      class="inline-flex min-h-[34px] cursor-grab touch-none select-none items-center gap-1.5 rounded-full border border-gold-500/45 bg-gold-500/[0.12] px-3 text-[11.5px] font-semibold text-ink-800"
    >
      <span class="min-w-2 text-center text-[9px] font-bold tabular-nums text-gold-600">
        {@index + 1}
      </span>
      <code class="font-bold">{@step.code}</code>
      <span class="font-medium text-ink-600">{@step.name}</span>
      <span
        data-reorder-ignore
        phx-click="sequence_draft_remove"
        phx-value-index={@index}
        class="grid size-4 cursor-pointer place-items-center rounded-full text-[13px] leading-none text-ink-400 hover:bg-ink-200 hover:text-ink-700"
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

  attr :id, :string, required: true
  attr :suggestions, :list, default: []
  attr :placeholder, :string, default: "+ Vincular passo..."
  attr :disabled, :boolean, default: false
  attr :search_event, :string, required: true
  attr :add_event, :string, required: true
  attr :rest, :global, include: ~w(phx-value-note-id)

  def step_search(assigns) do
    ~H"""
    <div class="relative">
      <form phx-change={@search_event} autocomplete="off" {@rest}>
        <input
          id={@id}
          type="text"
          name="term"
          value=""
          placeholder={@placeholder}
          disabled={@disabled}
          phx-debounce="200"
          class="w-full rounded-lg border border-ink-200 bg-ink-50/80 px-3 py-2 font-serif text-xs text-ink-700 outline-none transition-colors focus:border-accent-orange/40 disabled:opacity-60"
        />
      </form>
      <div
        :if={@suggestions != []}
        class="absolute left-0 right-0 top-[42px] z-20 overflow-hidden rounded-xl border border-ink-200 bg-ink-50 shadow-lg"
      >
        <button
          :for={step <- @suggestions}
          type="button"
          phx-click={@add_event}
          phx-value-id={step.id}
          phx-value-step-id={step.id}
          {@rest}
          class="flex w-full items-center justify-between gap-2 border-b border-ink-200/60 px-3 py-2.5 text-left last:border-b-0 hover:bg-ink-100"
        >
          <span class="min-w-0 truncate text-xs text-ink-800">
            <code class="font-bold text-accent-orange">{step.code}</code>
            {step.name}
          </span>
          <span class="shrink-0 text-[10px] font-semibold text-accent-orange">Adicionar</span>
        </button>
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
    <section
      id={@id}
      class="rounded-2xl border border-ink-200 border-l-[3px] border-l-accent-orange bg-ink-50 p-5 shadow-sm"
    >
      <div class="mb-3 flex items-start justify-between gap-3">
        <div class="min-w-0">
          <p
            :if={@eyebrow}
            class="mb-0.5 text-[11px] font-bold uppercase tracking-[0.16em] text-accent-orange"
          >
            {@eyebrow}
          </p>
          <h2 class="m-0 font-serif text-xl font-bold leading-snug text-ink-900">{@title}</h2>
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
    <section class="rounded-2xl border border-ink-200 bg-ink-50 p-5 shadow-sm">
      <div class="mb-3 flex items-center justify-between">
        <h2 class="m-0 font-serif text-lg font-bold text-ink-900">{@title}</h2>
        <span :if={@count_label} class="text-[11px] text-ink-400">{@count_label}</span>
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
        <p class={["mt-1.5 text-xs leading-6 text-ink-700", !@expanded && "line-clamp-2"]}>
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
        <p class="mt-1.5 text-xs leading-6 text-ink-700">{@note.content}</p>
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
  attr :accent, :atom, default: :orange, values: [:orange, :purple, :green]
  attr :badge_label, :string, default: nil
  attr :badge_tone, :atom, default: :neutral, values: [:neutral, :accent, :purple]
  attr :status_label, :string, default: nil
  attr :status_tone, :atom, default: :muted, values: [:muted, :success]
  attr :href, :string, default: nil
  slot :actions
  slot :footer

  def person_card(assigns) do
    ~H"""
    <div class={[
      "rounded-2xl border border-ink-200 border-l-[3px] bg-ink-50 px-4 py-3.5 shadow-sm",
      @accent == :orange && "border-l-accent-orange/70",
      @accent == :purple && "border-l-accent-purple/70",
      @accent == :green && "border-l-accent-green/70"
    ]}>
      <div class="flex items-center gap-3">
        <.maybe_user_link href={@href} class="flex min-w-0 flex-1 items-center gap-3 no-underline">
          <.user_avatar user={@user} size={:lg} />
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2">
              <p class="m-0 truncate font-serif text-base font-bold text-ink-900">
                {@user.name || @user.username}
              </p>
              <span
                :if={@badge_label}
                class={[
                  "shrink-0 rounded-full px-2 py-0.5 text-[9px] font-bold uppercase tracking-wide",
                  @badge_tone == :neutral && "bg-ink-200 text-ink-600",
                  @badge_tone == :accent && "bg-accent-orange/15 text-accent-orange",
                  @badge_tone == :purple && "bg-accent-purple/15 text-accent-purple"
                ]}
              >
                {@badge_label}
              </span>
            </div>
            <p class="m-0 mt-0.5 flex flex-wrap items-center gap-1.5 text-[11px] text-ink-500">
              <span>@{@user.username}</span>
              <span :if={@status_label} class="text-ink-300">·</span>
              <span
                :if={@status_label}
                class={[
                  "font-semibold",
                  @status_tone == :success && "text-accent-green",
                  @status_tone == :muted && "text-ink-400"
                ]}
              >
                {@status_label}
              </span>
            </p>
          </div>
        </.maybe_user_link>
        <div :if={@actions != []} class="flex shrink-0 items-center gap-1.5">
          {render_slot(@actions)}
        </div>
      </div>
      <div :if={@footer != []} class="mt-2.5 border-t border-ink-200/70 pt-2.5">
        {render_slot(@footer)}
      </div>
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

  attr :icon, :string, default: nil
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :tone, :atom, default: :gold, values: [:gold, :neutral]
  slot :action

  def empty_state(assigns) do
    ~H"""
    <div class={[
      "rounded-2xl border border-dashed px-5 py-8 text-center",
      @tone == :gold && "border-gold-500/30 bg-gold-500/[0.04]",
      @tone == :neutral && "border-ink-200 bg-ink-100/40"
    ]}>
      <.icon :if={@icon} name={@icon} class="mx-auto mb-2 size-6 text-ink-300" />
      <p class="m-0 font-serif text-sm font-bold text-ink-800">{@title}</p>
      <p :if={@description} class="mx-auto mt-1 max-w-sm text-xs leading-relaxed text-ink-500">
        {@description}
      </p>
      <div :if={@action != []} class="mt-3 flex justify-center">{render_slot(@action)}</div>
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
