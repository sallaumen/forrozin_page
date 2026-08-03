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
  # Caixa de selecao da programacao. Fora do <label> de proposito: o card tem
  # link dentro, e clicar em "Ver" nao pode marcar o checkbox.
  slot :select

  def workshop_card(assigns) do
    ~H"""
    <article
      id={"#{@id_prefix}-#{@workshop.id}"}
      class="flex flex-wrap items-center gap-x-4 gap-y-3 rounded-2xl border border-ink-200 bg-ink-50 p-4 shadow-sm transition-colors hover:border-ink-300"
    >
      <div :if={@select != []} class="shrink-0">{render_slot(@select)}</div>

      <%!-- Com flyer, o cartaz vira a ancora visual: a data continua na linha
      de baixo, entao nada se perde. --%>
      <img
        :if={@workshop.flyer_path}
        src={@workshop.flyer_path}
        alt={"Flyer de #{@workshop.title}"}
        loading="lazy"
        class="h-[54px] w-[54px] shrink-0 rounded-xl border border-ink-200 object-cover"
      />
      <.date_block :if={is_nil(@workshop.flyer_path)} datetime={@workshop.starts_at} />

      <div class="min-w-0 flex-1 basis-[55%]">
        <p class="m-0 line-clamp-2 font-serif text-[15px] font-bold tracking-tight text-ink-900">
          {@workshop.title}
        </p>
        <p class="m-0 mt-0.5 line-clamp-2 text-[12.5px] text-ink-500">
          {@workshop.organizer.name} · {schedule_label(@workshop)}{location_suffix(@workshop)}
        </p>

        <div class="mt-1.5 flex flex-wrap items-center gap-1.5">
          <.workshop_tag :if={programa_do(@workshop)} tone={:purple}>
            {programa_do(@workshop).title}
          </.workshop_tag>
          <.workshop_tag :if={@organizer?} tone={:neutral}>Você organiza</.workshop_tag>
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

  # ── Card de programação na agenda ────────────────────────────────────

  attr :program, :map, required: true
  attr :summary, :map, required: true
  attr :owner?, :boolean, default: false
  attr :enrolled_count, :integer, default: 0

  def program_card(assigns) do
    ~H"""
    <article
      id={"program-card-#{@program.id}"}
      class="flex flex-wrap items-center gap-x-4 gap-y-3 rounded-2xl border border-accent-purple/25 bg-ink-50 p-4 shadow-sm transition-colors hover:border-accent-purple/50"
    >
      <img
        :if={@program.flyer_path}
        src={@program.flyer_path}
        alt={"Flyer de #{@program.title}"}
        loading="lazy"
        class="h-[54px] w-[54px] shrink-0 rounded-xl border border-ink-200 object-cover"
      />
      <div
        :if={is_nil(@program.flyer_path)}
        class="flex h-[54px] w-[54px] shrink-0 items-center justify-center rounded-xl border border-accent-purple/25 bg-accent-purple/10"
      >
        <.icon name="hero-calendar-days" class="size-6 text-accent-purple" />
      </div>

      <div class="min-w-0 flex-1 basis-[55%]">
        <p class="m-0 line-clamp-2 font-serif text-[15px] font-bold tracking-tight text-ink-900">
          {@program.title}
        </p>
        <p class="m-0 mt-0.5 line-clamp-2 text-[12.5px] text-ink-500">
          {@program.owner.name} · {program_dates(@summary)}{location_suffix(@program)}
        </p>

        <div class="mt-1.5 flex flex-wrap items-center gap-1.5">
          <.workshop_tag tone={:purple}>Programação</.workshop_tag>
          <.workshop_tag :if={@owner?} tone={:neutral}>Você organiza</.workshop_tag>
          <.workshop_tag :if={@enrolled_count > 0 && !@owner?} tone={:green}>
            {inscricao_label(@enrolled_count)}
          </.workshop_tag>
          <span class="text-[11.5px] text-ink-400">{workshop_count_label(@summary.count)}</span>
        </div>
      </div>

      <.link
        navigate={~p"/programacao/#{@program.slug}"}
        class="w-full shrink-0 rounded-full bg-accent-purple px-4 py-2 text-center font-serif text-[13px] font-semibold text-white no-underline transition-colors hover:bg-accent-purple/90 sm:w-auto"
      >
        Ver programação
      </.link>
    </article>
    """
  end

  # Na busca o workshop sai solto mesmo estando numa programacao: sem esta
  # etiqueta nada na tela liga um ao outro.
  defp programa_do(%{program: %{title: _} = program}), do: program
  defp programa_do(_workshop), do: nil

  @doc "Ex.: Você está em 1 / Você está em 3"
  def inscricao_label(1), do: "Você está em 1"
  def inscricao_label(total), do: "Você está em #{total}"

  @doc "Intervalo de datas de uma programação, a partir do resumo agregado."
  def program_dates(%{starts_at: inicio, ends_at: fim}) do
    date_span(
      Brazil.to_local(inicio) |> DateTime.to_date(),
      Brazil.to_local(fim) |> DateTime.to_date()
    )
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

  # ── Galeria ──────────────────────────────────────────────────────────

  attr :media, :list, required: true
  attr :current_user, :map, default: nil
  attr :pode_apagar_tudo, :boolean, default: false

  def media_gallery(assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-2.5 sm:grid-cols-3">
      <figure
        :for={item <- @media}
        id={"media-#{item.id}"}
        class="group relative m-0 overflow-hidden rounded-xl border border-ink-200 bg-ink-100"
      >
        <img
          :if={item.kind == :photo}
          src={~p"/workshop-media/#{item.id}"}
          alt={item.caption || "Foto do workshop"}
          loading="lazy"
          class="aspect-square w-full object-cover"
        />

        <video
          :if={item.kind == :video}
          src={~p"/workshop-media/#{item.id}"}
          controls
          playsinline
          preload="metadata"
          class="aspect-square w-full bg-ink-900 object-cover"
        >
        </video>

        <span
          :if={item.official}
          class="absolute left-2 top-2 inline-flex items-center gap-1 rounded-full bg-gold-500/90 px-2 py-0.5 text-[10px] font-bold uppercase tracking-[0.4px] text-ink-900"
        >
          <.icon name="hero-star-solid" class="size-3" /> Oficial
        </span>

        <button
          :if={pode_apagar?(item, @current_user, @pode_apagar_tudo)}
          type="button"
          phx-click="remove_media"
          phx-value-id={item.id}
          data-confirm="Tirar esta mídia da galeria?"
          aria-label="Tirar da galeria"
          class="absolute right-2 top-2 cursor-pointer rounded-full border-0 bg-ink-900/70 p-1.5 text-ink-50 opacity-0 transition-opacity group-hover:opacity-100 focus:opacity-100"
        >
          <.icon name="hero-trash" class="size-3.5" />
        </button>

        <figcaption class="flex items-center gap-1.5 px-2 py-1.5 text-[11px] text-ink-500">
          <span class="truncate">{autor_da_media(item)}</span>
        </figcaption>
      </figure>
    </div>
    """
  end

  defp pode_apagar?(_item, nil, _admin?), do: false
  defp pode_apagar?(_item, _user, true), do: true
  defp pode_apagar?(item, user, _admin?), do: item.uploaded_by_id == user.id

  defp autor_da_media(%{uploaded_by: %{name: nome, username: username}}), do: nome || username
  defp autor_da_media(_item), do: "Alguém do workshop"

  # ── Caixa do pacote ──────────────────────────────────────────────────

  attr :program, :map, required: true
  attr :avulso_total, :integer, required: true
  attr :ja_comprou, :boolean, default: false
  attr :indisponivel, :string, default: nil

  def package_box(assigns) do
    ~H"""
    <div class="rounded-2xl border border-ink-200 border-l-[3px] border-l-accent-green bg-ink-50 p-4 shadow-sm">
      <p class="m-0 font-serif text-[24px] font-bold tracking-tight text-ink-900">
        {money_label(@program.price_cents)}
        <span class="text-[12px] font-normal text-ink-500">pela programação toda</span>
      </p>

      <p :if={economia(@program, @avulso_total) > 0} class="m-0 mt-1 text-[12.5px] text-accent-green">
        <b>Economiza {money_label(economia(@program, @avulso_total))}</b>
        em relação a pagar dia a dia.
      </p>

      <p :if={@program.payment_info} class="m-0 mt-1 text-[12.5px] leading-snug text-ink-500">
        {@program.payment_info}
      </p>

      <div
        :if={@ja_comprou}
        class="mt-3 rounded-xl border border-accent-green/30 bg-accent-green/10 px-4 py-3 text-center"
      >
        <p class="m-0 text-[13px] font-bold text-accent-green">
          <.icon name="hero-check-circle" class="size-4 -mt-0.5" /> Você tem a programação toda
        </p>
      </div>

      <button
        :if={!@ja_comprou && is_nil(@indisponivel)}
        type="button"
        phx-click="buy_package"
        phx-disable-with="Confirmando..."
        class="mt-3 w-full cursor-pointer rounded-full border-0 bg-accent-green px-5 py-3 font-serif text-[15px] font-semibold text-white transition-colors hover:bg-accent-green/90"
      >
        Quero a programação toda
      </button>

      <p
        :if={!@ja_comprou && @indisponivel}
        class="m-0 mt-3 rounded-xl bg-ink-200 px-4 py-3 text-center text-[12.5px] text-ink-600"
      >
        {@indisponivel}
      </p>
    </div>
    """
  end

  @doc "Quanto o pacote economiza contra a soma dos avulsos. Zero se não economiza."
  def economia(%{price_cents: pacote}, avulso_total)
      when is_integer(pacote) and is_integer(avulso_total) and avulso_total > pacote,
      do: avulso_total - pacote

  def economia(_program, _avulso_total), do: 0

  # ── Flyer ────────────────────────────────────────────────────────────

  attr :upload, :any, required: true
  attr :current_path, :string, default: nil
  attr :legenda, :string, default: "Cartaz de divulgação, o mesmo que você manda no WhatsApp."

  def flyer_field(assigns) do
    ~H"""
    <div class="mt-4">
      <p class="mb-1 text-[12.5px] font-bold text-ink-700">
        Flyer <span class="font-normal text-ink-400">(opcional)</span>
      </p>
      <p class="m-0 mb-2 text-[12px] leading-snug text-ink-500">{@legenda}</p>

      <div :if={@current_path} class="mb-2 flex items-start gap-3">
        <img
          src={@current_path}
          alt="Flyer atual"
          class="h-24 w-auto rounded-lg border border-ink-200 object-cover"
        />
        <button
          type="button"
          phx-click="remove_flyer"
          class="cursor-pointer rounded-full border border-ink-300 bg-ink-50 px-3 py-1.5 font-serif text-[12px] font-semibold text-ink-600"
        >
          Tirar flyer
        </button>
      </div>

      <.live_file_input
        upload={@upload}
        class="block w-full text-[12.5px] text-ink-600 file:mr-3 file:cursor-pointer file:rounded-full file:border-0 file:bg-ink-900 file:px-4 file:py-2 file:font-serif file:text-[12.5px] file:font-semibold file:text-ink-50"
      />

      <div :for={entry <- @upload.entries} class="mt-2 flex items-center gap-3">
        <.live_img_preview
          entry={entry}
          class="h-24 w-auto rounded-lg border border-ink-200 object-cover"
        />
        <span class="text-[12px] text-ink-500">{entry.progress}%</span>
      </div>

      <div :for={entry <- @upload.entries}>
        <p
          :for={erro <- upload_errors(@upload, entry)}
          class="m-0 mt-1 text-[12px] font-semibold text-accent-red"
        >
          {erro_de_upload(erro)}
        </p>
      </div>
    </div>
    """
  end

  @doc false
  def erro_de_upload(:too_large), do: "Imagem grande demais. O limite é 8 MB."
  def erro_de_upload(:not_accepted), do: "Formato não aceito. Use JPG, PNG ou WEBP."
  def erro_de_upload(:too_many_files), do: "Só um flyer por vez."
  def erro_de_upload(_outro), do: "Não deu para carregar essa imagem."

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

  @doc """
  Resumo de uma programação: quantos workshops e em que dias.

  Ex.: `2 workshops · 14 e 15 de agosto`, `15 workshops · 12 a 18 de fevereiro`
  """
  def program_span([], _count), do: "Nenhum workshop ainda"

  def program_span(days, count) do
    datas = Enum.map(days, fn {date, _} -> date end)
    "#{workshop_count_label(count)} · #{date_span(List.first(datas), List.last(datas))}"
  end

  defp workshop_count_label(1), do: "1 workshop"
  defp workshop_count_label(count), do: "#{count} workshops"

  defp date_span(date, date), do: Brazil.strftime(date, "%d de %B")

  # Mesmo mes nomeia o mes uma vez so: "07 e 08 de agosto", "12 a 18 de
  # fevereiro". Dia sempre com dois digitos, como no resto do app.
  defp date_span(%{month: m, year: y} = inicio, %{month: m, year: y} = fim) do
    "#{Brazil.strftime(inicio, "%d")} #{juntor(inicio, fim)} #{Brazil.strftime(fim, "%d de %B")}"
  end

  defp date_span(inicio, fim) do
    "#{Brazil.strftime(inicio, "%d de %B")} a #{Brazil.strftime(fim, "%d de %B")}"
  end

  defp juntor(inicio, fim) do
    if Date.diff(fim, inicio) == 1, do: "e", else: "a"
  end

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
