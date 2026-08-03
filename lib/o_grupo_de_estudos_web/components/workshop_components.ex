defmodule OGrupoDeEstudosWeb.WorkshopComponents do
  @moduledoc """
  Blocos visuais dos workshops. Apresentacionais: recebem dados prontos e
  emitem eventos por attr, sem consultar nada.
  """

  use Phoenix.Component
  use OGrupoDeEstudosWeb, :verified_routes

  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]

  alias OGrupoDeEstudos.Brazil
  alias OGrupoDeEstudos.Workshops.Workshop

  @month_abbr {"jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"}

  # ── Bloco de data (dia grande + mês) ─────────────────────────────────

  attr :datetime, :any, required: true

  def date_block(assigns) do
    local = Brazil.to_local(assigns.datetime)
    assigns = assign(assigns, day: local.day, month: elem(@month_abbr, local.month - 1))

    ~H"""
    <div class="flex h-[54px] w-[54px] shrink-0 flex-col items-center justify-center rounded-xl border border-ink-200 bg-ink-100 leading-none">
      <span class="font-serif text-[21px] font-bold tracking-tight text-ink-900">{@day}</span>
      <span class="mt-0.5 text-[9px] font-bold uppercase tracking-[1.4px] text-ink-500">
        {@month}
      </span>
    </div>
    """
  end

  # ── Card da agenda ───────────────────────────────────────────────────

  attr :workshop, :map, required: true
  attr :enrolled_count, :integer, default: 0
  attr :enrolled?, :boolean, default: false
  attr :organizer?, :boolean, default: false
  # O mesmo workshop sai em duas listas da agenda: sem prefixo os dois cards
  # teriam o mesmo id e o LiveView atualizaria o errado.
  attr :id_prefix, :string, default: "workshop-card"

  def workshop_card(assigns) do
    ~H"""
    <article
      id={"#{@id_prefix}-#{@workshop.id}"}
      class="flex flex-wrap items-center gap-x-4 gap-y-3 rounded-2xl border border-ink-200 bg-ink-50 p-4 shadow-sm transition-colors hover:border-ink-300"
    >
      <.date_block datetime={@workshop.starts_at} />

      <div class="min-w-0 flex-1 basis-[55%]">
        <p class="m-0 line-clamp-2 font-serif text-[15px] font-bold tracking-tight text-ink-900">
          {@workshop.title}
        </p>
        <p class="m-0 mt-0.5 line-clamp-2 text-[12.5px] text-ink-500">
          {@workshop.organizer.name} · {schedule_label(@workshop)}{location_suffix(@workshop)}
        </p>

        <div class="mt-1.5 flex flex-wrap items-center gap-1.5">
          <.workshop_tag :if={@organizer?} tone={:purple}>Você organiza</.workshop_tag>
          <.workshop_tag :if={@enrolled? && !@organizer?} tone={:green}>
            Você está inscrito
          </.workshop_tag>
          <.workshop_tag :if={Workshop.free?(@workshop)} tone={:blue}>Gratuito</.workshop_tag>
          <.workshop_tag :if={!Workshop.free?(@workshop)} tone={:neutral}>
            {price_label(@workshop)}
          </.workshop_tag>
          <.workshop_tag :if={Workshop.full?(@workshop, @enrolled_count)} tone={:red}>
            Esgotado
          </.workshop_tag>
          <span :if={@enrolled_count > 0} class="text-[11.5px] text-ink-400">
            {people_label(@enrolled_count)}
          </span>
        </div>
      </div>

      <.link
        navigate={~p"/workshops/#{@workshop.slug}"}
        class="w-full shrink-0 rounded-full bg-accent-orange px-4 py-2 text-center font-serif text-[13px] font-semibold text-white no-underline transition-colors hover:bg-accent-orange/90 sm:w-auto"
      >
        {if @organizer?, do: "Gerenciar", else: "Ver"}
      </.link>
    </article>
    """
  end

  attr :tone, :atom, default: :neutral, values: [:neutral, :green, :purple, :blue, :red, :orange]
  slot :inner_block, required: true

  def workshop_tag(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center rounded-full px-2.5 py-0.5 text-[10px] font-bold uppercase tracking-[0.4px]",
      @tone == :neutral && "bg-ink-200 text-ink-600",
      @tone == :green && "bg-accent-green/15 text-accent-green",
      @tone == :purple && "bg-accent-purple/15 text-accent-purple",
      @tone == :blue && "bg-accent-blue/15 text-accent-blue",
      @tone == :red && "bg-accent-red/15 text-accent-red",
      @tone == :orange && "bg-accent-orange/15 text-accent-orange"
    ]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  # ── Chips de período ─────────────────────────────────────────────────

  attr :active, :string, required: true
  attr :event, :string, default: "filter_period"

  def period_filter(assigns) do
    assigns =
      assign(assigns, :options, [
        {"upcoming", "Em breve"},
        {"week", "Esta semana"},
        {"month", "Este mês"},
        {"year", "Este ano"},
        {"past", "Já aconteceram"}
      ])

    ~H"""
    <div class="flex flex-wrap gap-1.5">
      <button
        :for={{value, label} <- @options}
        type="button"
        phx-click={@event}
        phx-value-period={value}
        class={[
          "cursor-pointer whitespace-nowrap rounded-full border px-3 py-1.5 font-serif text-[12px] font-semibold transition-colors",
          @active == value && "border-ink-900 bg-ink-900 text-ink-50",
          @active != value && "border-ink-300 bg-ink-50 text-ink-600 hover:border-ink-400"
        ]}
      >
        {label}
      </button>
    </div>
    """
  end

  # ── Estado vazio ─────────────────────────────────────────────────────

  attr :title, :string, required: true
  attr :description, :string, default: nil
  slot :action

  def workshop_empty(assigns) do
    ~H"""
    <div class="rounded-2xl border border-dashed border-ink-300 bg-ink-50/60 px-6 py-10 text-center">
      <.icon name="hero-calendar-days" class="size-7 text-ink-300" />
      <p class="m-0 mt-2 font-serif text-[15px] font-bold text-ink-800">{@title}</p>
      <p :if={@description} class="m-0 mt-1 text-[13px] text-ink-500">{@description}</p>
      <div :if={@action != []} class="mt-4">{render_slot(@action)}</div>
    </div>
    """
  end

  # ── Helpers de texto ─────────────────────────────────────────────────

  @doc """
  Ex.: `sábado, 16 de agosto · 14h às 18h`, ou `16 a 18 de agosto · começa 14h`
  quando o workshop atravessa dias.

  Quem decide se é um dia ou vários é o calendário local: um evento que vai
  das 20h às 23h de Brasília cruza a meia-noite em UTC e continua sendo uma
  noite só.
  """
  def schedule_label(%{starts_at: starts_at, ends_at: ends_at} = workshop) do
    day_label(Brazil.to_local(starts_at), local_or_nil(ends_at), workshop)
  end

  defp local_or_nil(nil), do: nil
  defp local_or_nil(datetime), do: Brazil.to_local(datetime)

  defp day_label(start_local, nil, workshop), do: single_day(start_local, workshop)

  defp day_label(%{year: y, month: m, day: d} = start_local, %{year: y, month: m, day: d}, ws),
    do: single_day(start_local, ws)

  defp day_label(start_local, end_local, _workshop), do: multi_day(start_local, end_local)

  defp single_day(start_local, workshop) do
    "#{Brazil.strftime(start_local, "%A, %d de %B")} · #{time_range(workshop)}"
  end

  # Atravessando dias o que importa é até quando vai, não a hora de encerrar
  # no último dia: "12 a 13 de setembro · 14h às 18h" leria como duas coisas.
  defp multi_day(start_local, end_local) do
    "#{day_span(start_local, end_local)} · começa #{local_hour(start_local)}"
  end

  defp day_span(%{month: m} = start_local, %{month: m} = end_local),
    do: "#{start_local.day} a #{Brazil.strftime(end_local, "%d de %B")}"

  defp day_span(start_local, end_local),
    do: "#{month_day(start_local)} a #{month_day(end_local)}"

  defp month_day(local), do: Brazil.strftime(local, "%d de %B")

  @doc "Ex.: 14h às 18h (ou só 14h quando não tem fim)"
  def time_range(%{starts_at: starts_at, ends_at: nil}), do: hour_label(starts_at)

  def time_range(%{starts_at: starts_at, ends_at: ends_at}),
    do: "#{hour_label(starts_at)} às #{hour_label(ends_at)}"

  @doc "Preço formatado, ou Gratuito."
  def price_label(%{price_cents: nil}), do: "Gratuito"
  def price_label(%{price_cents: 0}), do: "Gratuito"
  def price_label(%{price_cents: cents}), do: money_label(cents)

  @doc """
  Valor em reais. Diferente de `price_label/1`, zero aqui é um número: no
  painel do organizador "R$ 0 recebido" é o que aconteceu, "Gratuito" não.
  """
  def money_label(cents) when is_integer(cents), do: reais_label(div(cents, 100), rem(cents, 100))

  defp reais_label(reais, 0), do: "R$ #{reais}"

  defp reais_label(reais, centavos),
    do: "R$ #{reais},#{String.pad_leading(to_string(centavos), 2, "0")}"

  @doc "Rótulo do botão de curtir: some o número quando ninguém curtiu ainda."
  def like_label(true, 1), do: "Você curtiu"
  def like_label(true, count), do: "Você e mais #{count - 1}"
  def like_label(false, 0), do: "Curtir"
  def like_label(false, count), do: "Curtir · #{count}"

  @doc "Ex.: 1 inscrito / 32 inscritos"
  def people_label(1), do: "1 inscrito"
  def people_label(count), do: "#{count} inscritos"

  @doc "Rótulo do estado de pagamento (visível só para o organizador)."
  def payment_status_label(:paid), do: "Pago"
  def payment_status_label(:waived), do: "Isento"
  def payment_status_label(_status), do: "Aguardando"

  @doc "Percentual de vagas preenchidas, limitado a 100."
  def vagas_percent(_enrolled, nil), do: 0
  def vagas_percent(_enrolled, 0), do: 100

  def vagas_percent(enrolled, capacity) do
    enrolled |> Kernel./(capacity) |> Kernel.*(100) |> round() |> min(100)
  end

  @doc """
  Como pagar. A chave Pix costuma ser CPF ou telefone do organizador, então
  só aparece para quem se inscreveu (`reveal?`); os outros veem o preço e a
  informação de que o acerto é direto com quem organiza.
  """
  def payment_hint(workshop, reveal? \\ true)

  def payment_hint(%{payment_info: info}, true) when is_binary(info) and info != "", do: info

  def payment_hint(%{organizer: %{name: name}}, _reveal?),
    do: "O pagamento é combinado direto com #{first_name(name)}."

  def payment_hint(_workshop, _reveal?), do: "O pagamento é combinado direto com quem organiza."

  defp first_name(nil), do: "quem organiza"
  defp first_name(name), do: name |> String.split(" ") |> List.first()

  defp location_suffix(%{location: nil}), do: ""
  defp location_suffix(%{location: ""}), do: ""
  defp location_suffix(%{location: location}), do: " · #{location}"

  defp hour_label(datetime), do: local_hour(Brazil.to_local(datetime))

  defp local_hour(%{minute: 0} = local), do: "#{local.hour}h"

  defp local_hour(local),
    do: "#{local.hour}h#{String.pad_leading(to_string(local.minute), 2, "0")}"
end
