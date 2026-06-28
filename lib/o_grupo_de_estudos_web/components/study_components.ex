defmodule OGrupoDeEstudosWeb.StudyComponents do
  @moduledoc """
  Function components compartilhados da área de Estudos (/study e
  /study/shared/:id).

  Centraliza os blocos que se repetem entre "Meu estudo", "Meus professores",
  "Meus alunos" e o diário compartilhado: cabeçalho de seção, abas, cartão de
  diário (nota de hoje), histórico de notas, chips de passo, cartões de
  pessoa/estatística, consistência e estados vazios.

  Tudo é apresentacional: os eventos (`save`, `search`, `add`, `remove`, ...)
  chegam por atributo, então cada LiveView reaproveita o mesmo markup passando
  os seus próprios handlers (mesmo padrão de `UI.GoalsBoard`).
  """

  use OGrupoDeEstudosWeb, :html

  import OGrupoDeEstudosWeb.UI.UserAvatar

  @weekday_labels {"S", "T", "Q", "Q", "S", "S", "D"}

  # ── Abas principais ──────────────────────────────────────────────────

  attr :active, :string, required: true, values: ~w(personal teachers students)
  attr :is_teacher, :boolean, default: false
  attr :pending_count, :integer, default: 0

  def study_tabs(assigns) do
    ~H"""
    <div class="sticky top-[48px] md:top-[52px] z-30 border-b border-ink-300/40 bg-ink-100/95 backdrop-blur-sm">
      <div class="mx-auto max-w-[1500px] px-4 py-2.5 sm:px-6 lg:px-8">
        <div
          role="tablist"
          class="inline-flex items-center gap-0.5 rounded-full border border-ink-200 bg-ink-200/60 p-1"
        >
          <.tab_button tab="personal" active={@active} label="Meu estudo" />
          <.tab_button tab="teachers" active={@active} label="Meus professores" />
          <.tab_button :if={@is_teacher} tab="students" active={@active} label="Meus alunos">
            <span
              :if={@pending_count > 0}
              class="ml-1.5 inline-flex min-w-[18px] items-center justify-center rounded-full bg-accent-red px-1.5 py-0.5 text-[10px] font-bold leading-none text-white"
            >
              {@pending_count}
            </span>
          </.tab_button>
        </div>
      </div>
    </div>
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

  # ── Cabeçalho de seção (eyebrow + título + ação) ─────────────────────

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

  # ── Botão de ação primário (laranja) e secundário (ghost) ────────────

  attr :tone, :atom, default: :primary, values: [:primary, :ghost]
  attr :icon, :string, default: nil

  attr :rest, :global,
    include: ~w(phx-click phx-value-id phx-value-tab navigate href data-confirm)

  slot :inner_block, required: true

  def action_button(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "inline-flex items-center gap-1.5 rounded-full px-4 py-2 font-serif text-sm font-semibold no-underline transition-colors",
        @tone == :primary && "bg-accent-orange text-white hover:bg-accent-orange/90",
        @tone == :ghost &&
          "border border-ink-300 bg-ink-50 text-ink-700 hover:border-ink-400 hover:text-ink-900"
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

  # ── Sidebar block (card com título) ──────────────────────────────────

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

  # ── Card de consistência (dots por dia da semana) ────────────────────

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
          {if @monthly_count == 1, do: "registro", else: "registros"} em {@month_name}
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

  # ── Card de estatística ──────────────────────────────────────────────

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

  # ── Chip de passo vinculado ──────────────────────────────────────────

  attr :step, :map, required: true
  attr :removable, :boolean, default: false
  attr :remove_event, :string, default: nil
  attr :rest, :global, include: ~w(phx-value-id phx-value-note-id phx-value-step-id disabled)

  def step_pill(assigns) do
    ~H"""
    <button
      :if={@removable}
      type="button"
      phx-click={@remove_event}
      class="group inline-flex items-center gap-1.5 rounded-full border border-accent-orange/25 bg-accent-orange/[0.08] px-2.5 py-1 text-[11px] font-semibold text-accent-orange transition-colors hover:bg-accent-orange/15 disabled:cursor-default disabled:opacity-70"
      {@rest}
    >
      <code class="font-bold">{@step.code}</code>
      <span class="font-normal text-ink-600">{@step.name}</span>
      <.icon name="hero-x-mark" class="size-3 text-accent-orange/60 group-hover:text-accent-orange" />
    </button>
    <span
      :if={!@removable}
      class="inline-flex items-center gap-1.5 rounded-full border border-accent-orange/20 bg-accent-orange/10 px-2.5 py-0.5 text-[10px] text-accent-orange"
    >
      <code class="font-bold">{@step.code}</code>
      <span class="text-ink-600">{@step.name}</span>
    </span>
    """
  end

  # ── Dropdown de busca de passos ──────────────────────────────────────

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

  # ── Cartão do diário (nota de hoje) ──────────────────────────────────

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

  # ── Histórico de notas anteriores ────────────────────────────────────

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
        <.step_pill :for={step <- @note.related_steps} step={step} />
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

  # ── Cartão de pessoa (professor / aluno) ─────────────────────────────

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

  # ── Estado vazio ─────────────────────────────────────────────────────

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

  # ── Helpers ──────────────────────────────────────────────────────────

  defp weekday_label(dow), do: elem(@weekday_labels, dow - 1)
end
