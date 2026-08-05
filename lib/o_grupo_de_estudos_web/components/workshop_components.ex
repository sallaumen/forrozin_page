defmodule OGrupoDeEstudosWeb.WorkshopComponents do
  @moduledoc """
  Visual blocks of the workshops. Presentational: they take ready data and emit
  events through attrs, querying nothing.
  """

  use Phoenix.Component
  use OGrupoDeEstudosWeb, :verified_routes

  import OGrupoDeEstudosWeb.CoreComponents, only: [icon: 1]
  import OGrupoDeEstudosWeb.UI.UserAvatar, only: [user_avatar: 1]

  alias OGrupoDeEstudos.Brazil
  alias OGrupoDeEstudos.Workshops.Workshop

  @month_abbr {"jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"}

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

  attr :workshop, :map, required: true
  attr :enrolled_count, :integer, default: 0
  attr :enrolled?, :boolean, default: false
  attr :organizer?, :boolean, default: false
  # The same workshop shows up in two agenda lists: without a prefix both cards
  # would share an id and the LiveView would update the wrong one.
  attr :id_prefix, :string, default: "workshop-card"
  # Program selection box. Outside the <label> on purpose: the card has a link
  # inside it, and clicking "Ver" must not tick the checkbox.
  slot :select

  @doc """
  One line of the community agenda.

  It used to be a card carrying up to six coloured badges, a 54px smudge of the
  poster and a dotted train that ended in the full street address. Here the date
  is the rail you scan, the poster keeps its presence on the workshop page, and
  the state of the class is said once in words.
  """
  def workshop_card(assigns) do
    assigns =
      assigns
      |> assign(:sold_out?, Workshop.full?(assigns.workshop, assigns.enrolled_count))
      |> assign(:seats, seats_label(assigns.workshop, assigns.enrolled_count))
      |> assign(:program, program_of(assigns.workshop))

    ~H"""
    <article
      id={"#{@id_prefix}-#{@workshop.id}"}
      class="flex items-baseline gap-3 border-t border-ink-200 py-3.5 sm:gap-4"
    >
      <div :if={@select != []} class="shrink-0 self-center">{render_slot(@select)}</div>

      <.date_block datetime={@workshop.starts_at} />

      <div class="min-w-0 flex-1">
        <p class="m-0 font-serif text-[15px] font-bold leading-snug tracking-tight sm:text-[16px]">
          <.icon
            :if={@workshop.visibility == :private}
            name="hero-lock-closed"
            class="-mt-1 mr-1 size-3.5 text-ink-500"
          />
          <.link
            navigate={~p"/workshops/#{@workshop.slug}"}
            class="text-ink-900 no-underline hover:underline"
          >
            {@workshop.title}
          </.link>
        </p>

        <%!-- Rosto pequeno junto do nome: quem passa os olhos na agenda
        reconhece o professor antes de ler. --%>
        <p class="m-0 mt-1 flex flex-wrap items-center gap-x-2 gap-y-1 font-sans text-[12px] leading-snug text-ink-500">
          <span class="inline-flex items-center gap-1">
            <.user_avatar user={@workshop.organizer} size={:xs} />
            <span class="font-semibold text-ink-700">{@workshop.organizer.name}</span>
          </span>
          <span>{time_and_place(@workshop)}</span>
        </p>

        <p class="m-0 mt-1 flex flex-wrap items-center gap-x-3 gap-y-0.5 font-sans text-[12px] leading-snug text-ink-500">
          <span class="font-semibold text-ink-700">{price_label(@workshop)}</span>
          <span :if={@seats}>{@seats}</span>
          <span :if={@sold_out?} class="font-semibold text-accent-red">Esgotado</span>
          <span :if={@workshop.visibility == :private}>Por aprovação</span>
          <span :if={@organizer?}>Você organiza</span>
          <span :if={@enrolled? && !@organizer?} class="text-accent-green">Você está inscrito</span>
          <.link
            :if={@program}
            navigate={~p"/programs/#{@program.slug}"}
            class="text-ink-500 underline decoration-ink-300 underline-offset-2 hover:text-ink-800"
          >
            {@program.title}
          </.link>
        </p>
      </div>

      <.link
        navigate={~p"/workshops/#{@workshop.slug}"}
        class="inline-flex min-h-11 shrink-0 items-center self-center rounded-full border border-ink-300 px-3.5 text-center font-serif text-[12.5px] font-semibold text-ink-700 no-underline transition-colors hover:border-ink-400 sm:min-h-9"
      >
        {if @organizer?, do: "Gerenciar", else: "Ver"}
      </.link>
    </article>
    """
  end

  # Hora e lugar numa linha só: o endereço completo é da página do workshop,
  # onde quem já está a caminho vai procurar.
  defp time_and_place(workshop) do
    [schedule_label(workshop), place_only(workshop)]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  defp place_only(%Workshop{location: location}) when is_binary(location) and location != "",
    do: location

  defp place_only(_workshop), do: nil

  slot :inner_block, required: true

  @doc """
  A section head the way a printed programme sets one.

  It replaces the uppercase eyebrow every block on these pages used to wear: when
  the photo gallery, the payment label and the conversation all carry the same
  10px caps, none of them is a heading anymore.
  """
  def section_heading(assigns) do
    ~H"""
    <h2 class="brand-display is-title m-0 mb-3 text-[16px] font-semibold tracking-tight text-ink-800">
      {render_slot(@inner_block)}
    </h2>
    """
  end

  attr :workshop, :map, required: true
  attr :enrolled_count, :integer, default: 0
  attr :enrolled?, :boolean, default: false
  attr :selectable?, :boolean, default: false
  attr :selected?, :boolean, default: false

  @doc """
  One line of the day, on a programme instead of on a card.

  The day heading above already says the date and the header already says who runs
  it and in which city, so the row keeps only what tells one class from the other:
  the hour, the name, the price and how much room is left. The address stays on
  the workshop page, where whoever is already on the way goes looking for it.
  """
  def agenda_row(assigns) do
    {starts, ends} = rail_hours(assigns.workshop)

    assigns =
      assigns
      |> assign(:starts_hour, starts)
      |> assign(:ends_hour, ends)
      |> assign(:sold_out?, Workshop.full?(assigns.workshop, assigns.enrolled_count))
      |> assign(:seats, seats_label(assigns.workshop, assigns.enrolled_count))

    ~H"""
    <article
      id={"agenda-#{@workshop.id}"}
      class="flex items-baseline gap-3 border-t border-ink-200 py-3.5 sm:gap-4"
    >
      <%!-- Picking a day is not enrolling in it: the checkbox waits for the confirm
      at the end of the list, and whoever is already in gets a check in its place. --%>
      <label
        :if={@selectable?}
        class="-my-2 flex min-h-11 shrink-0 cursor-pointer items-center self-center py-2"
      >
        <input
          type="checkbox"
          id={"pick-#{@workshop.id}"}
          checked={@selected?}
          phx-click="toggle_selection"
          phx-value-id={@workshop.id}
          aria-label={"Marcar #{@workshop.title}"}
          class="size-[18px] cursor-pointer accent-accent-orange"
        />
      </label>
      <.icon
        :if={@enrolled?}
        name="hero-check-circle-solid"
        class="size-[18px] shrink-0 self-center text-accent-green"
      />

      <p class="m-0 w-[3.1rem] shrink-0 font-sans leading-tight sm:w-[3.4rem]">
        <span class="block text-[15px] font-semibold tabular-nums text-ink-900">
          {@starts_hour}
        </span>
        <span :if={@ends_hour} class="block text-[11.5px] tabular-nums text-ink-500">
          {@ends_hour}
        </span>
      </p>

      <div class="min-w-0 flex-1">
        <p class="m-0 font-serif text-[15px] font-bold leading-snug tracking-tight sm:text-[16px]">
          <.icon
            :if={@workshop.visibility == :private}
            name="hero-lock-closed"
            class="-mt-1 mr-1 size-3.5 text-ink-500"
          />
          <.link
            navigate={~p"/workshops/#{@workshop.slug}"}
            class="text-ink-900 no-underline hover:underline"
          >
            {@workshop.title}
          </.link>
        </p>

        <p class="m-0 mt-1 flex flex-wrap items-center gap-x-3 gap-y-0.5 font-sans text-[12px] leading-snug text-ink-500">
          <span class="font-semibold text-ink-700">{price_label(@workshop)}</span>
          <span :if={@seats}>{@seats}</span>
          <span :if={@sold_out?} class="font-semibold text-accent-red">Esgotado</span>
          <span :if={@enrolled?} class="text-accent-green">Você está inscrito</span>
          <span :if={@workshop.status == :draft}>Rascunho</span>
        </p>
      </div>
    </article>
    """
  end

  @doc """
  The two hours a programme stacks on the left rail.

  Only the start when the class runs into the next day: printing "23h" under "20h"
  would read as a class that ends three hours before it begins.
  """
  def rail_hours(%{starts_at: starts_at, ends_at: nil}),
    do: {hour_label(starts_at), nil}

  def rail_hours(%{starts_at: starts_at, ends_at: ends_at}) do
    starts_local = Brazil.to_local(starts_at)
    ends_local = Brazil.to_local(ends_at)

    {local_hour(starts_local), same_day_hour(starts_local, ends_local)}
  end

  defp same_day_hour(%{year: y, month: m, day: d}, %{year: y, month: m, day: d} = ends_local),
    do: local_hour(ends_local)

  defp same_day_hour(_starts_local, _ends_local), do: nil

  @doc "How full a class is: seats out of capacity, or just how many people came."
  def seats_label(%{capacity: nil}, 0), do: nil
  def seats_label(%{capacity: nil}, count), do: people_label(count)
  def seats_label(%{capacity: 1}, count), do: "#{count} de 1 vaga"
  def seats_label(%{capacity: capacity}, count), do: "#{count} de #{capacity} vagas"

  attr :program, :map, required: true
  attr :summary, :map, required: true
  attr :owner?, :boolean, default: false
  attr :enrolled_count, :integer, default: 0

  @doc """
  A programme on the agenda, in the same grammar as a workshop.

  It used to be the purple species of card: purple border, purple badge, purple
  button, next to the orange ones. What tells a programme from a class is that it
  holds several days, and the line says so.
  """
  def program_card(assigns) do
    ~H"""
    <article
      id={"program-card-#{@program.id}"}
      class="flex items-baseline gap-3 border-t border-ink-200 py-3.5 sm:gap-4"
    >
      <div class="flex h-[54px] w-[54px] shrink-0 flex-col items-center justify-center rounded-xl border border-ink-200 bg-ink-100 leading-none">
        <.icon name="hero-calendar-days" class="size-5 text-ink-500" />
      </div>

      <div class="min-w-0 flex-1">
        <p class="m-0 font-serif text-[15px] font-bold leading-snug tracking-tight sm:text-[16px]">
          <.link
            navigate={~p"/programs/#{@program.slug}"}
            class="text-ink-900 no-underline hover:underline"
          >
            {@program.title}
          </.link>
        </p>

        <p class="m-0 mt-1 font-sans text-[12px] leading-snug text-ink-500">
          <b class="font-semibold text-ink-700">{@program.owner.name}</b>
          · {program_dates(@summary)}{location_suffix(@program)}
        </p>

        <p class="m-0 mt-1 flex flex-wrap items-center gap-x-3 gap-y-0.5 font-sans text-[12px] leading-snug text-ink-500">
          <span class="font-semibold text-ink-700">{workshop_count_label(@summary.count)}</span>
          <span :if={@owner?}>Você organiza</span>
          <span :if={@enrolled_count > 0 && !@owner?} class="text-accent-green">
            {enrollment_label(@enrolled_count)}
          </span>
        </p>
      </div>

      <.link
        navigate={~p"/programs/#{@program.slug}"}
        class="inline-flex min-h-11 shrink-0 items-center self-center rounded-full border border-ink-300 px-3.5 text-center font-serif text-[12.5px] font-semibold text-ink-700 no-underline transition-colors hover:border-ink-400 sm:min-h-9"
      >
        Ver
      </.link>
    </article>
    """
  end

  # In a search the workshop shows up loose even when it belongs to a program:
  # without this tag nothing on screen connects the two.
  # Precisa do slug: na agenda o nome da programação virou o link para ela, em
  # vez de uma etiqueta roxa que só dizia que ela existe.
  defp program_of(%{program: %{title: _, slug: _} = program}), do: program
  defp program_of(_workshop), do: nil

  @doc "For instance: Você está em 1 / Você está em 3"
  def enrollment_label(1), do: "Você está em 1"
  def enrollment_label(total), do: "Você está em #{total}"

  @doc "Date range of a program, from the aggregated summary."
  def program_dates(%{starts_at: inicio, ends_at: fim}) do
    date_span(
      Brazil.to_local(inicio) |> DateTime.to_date(),
      Brazil.to_local(fim) |> DateTime.to_date()
    )
  end

  attr :tone, :atom,
    default: :neutral,
    values: [:neutral, :green, :purple, :blue, :red, :orange, :gold]

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
      @tone == :orange && "bg-accent-orange/15 text-accent-orange",
      @tone == :gold && "bg-gold-500/20 text-gold-600"
    ]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

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
          "min-h-11 cursor-pointer whitespace-nowrap rounded-full border px-3.5 font-serif text-[12px] font-semibold transition-colors sm:min-h-9",
          @active == value && "border-ink-900 bg-ink-900 text-ink-50",
          @active != value && "border-ink-300 bg-ink-50 text-ink-600 hover:border-ink-400"
        ]}
      >
        {label}
      </button>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, default: nil
  slot :action

  # Nothing there yet is a sentence, not a framed announcement: the dashed box and
  # the calendar icon dressed an absence up as if it were an item.
  def workshop_empty(assigns) do
    ~H"""
    <div class="border-t border-ink-200 py-8">
      <p class="brand-display is-title m-0 text-[16px] font-semibold tracking-tight text-ink-800">
        {@title}
      </p>
      <p :if={@description} class="m-0 mt-1.5 font-sans text-[13px] text-ink-500">
        {@description}
      </p>
      <div :if={@action != []} class="mt-4">{render_slot(@action)}</div>
    </div>
    """
  end

  attr :receipt, :map, default: nil
  attr :upload, :map, required: true
  attr :whatsapp_link, :string, default: nil

  @doc """
  Where the receipt of a payment goes up.

  Both paths sit side by side on purpose: the app one lands next to the payment
  control, and WhatsApp is where people already are. Which one wins is a question
  the numbers answer, not the layout.
  """
  def receipt_box(assigns) do
    ~H"""
    <div>
      <p class="m-0 font-sans text-[10.5px] font-semibold uppercase tracking-[1.4px] text-ink-500">
        Comprovante
      </p>

      <p
        :if={sent?(@receipt)}
        class="m-0 mt-1.5 flex items-start gap-1.5 font-sans text-[12.5px] leading-snug text-ink-700"
      >
        <.icon name="hero-check-circle-solid" class="mt-0.5 size-4 shrink-0 text-accent-green" />
        <span>Enviado em {Brazil.format_datetime_full(@receipt.sent_at)}</span>
      </p>

      <p :if={!sent?(@receipt)} class="m-0 mt-1 font-sans text-[12px] leading-snug text-ink-500">
        Mande por aqui e quem organiza vê junto com a sua inscrição. Imagem ou PDF, até 10 MB.
      </p>

      <form id="receipt-form" phx-submit="send_receipt" phx-change="validate_receipt" class="mt-2">
        <label
          for={@upload.ref}
          class="inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-full border border-ink-300 px-4 font-serif text-[12.5px] font-semibold text-ink-700 transition-colors hover:border-ink-400 sm:min-h-9"
        >
          <.icon name="hero-paper-clip" class="size-4" /> {choose_label(@receipt)}
        </label>
        <.live_file_input upload={@upload} class="sr-only" />

        <div :for={entry <- @upload.entries} class="mt-2 flex items-center gap-3 font-sans">
          <span class="min-w-0 truncate text-[12px] text-ink-500">{entry.client_name}</span>
          <span class="shrink-0 text-[12px] font-bold text-ink-700">{entry.progress}%</span>
        </div>

        <p
          :for={error <- receipt_errors(@upload)}
          class="m-0 mt-1 font-sans text-[12px] font-semibold text-accent-red"
        >
          {receipt_upload_error(error)}
        </p>

        <button
          :if={@upload.entries != []}
          type="submit"
          phx-disable-with="Enviando..."
          class="mt-2 min-h-11 cursor-pointer rounded-full border-0 bg-ink-900 px-4 font-serif text-[12.5px] font-semibold text-ink-50 sm:min-h-9"
        >
          Enviar comprovante
        </button>
      </form>

      <div class="flex flex-wrap items-center gap-x-4 font-sans">
        <a
          :if={@whatsapp_link}
          href={@whatsapp_link}
          phx-click="receipt_via_whatsapp"
          target="_blank"
          rel="noopener noreferrer"
          class="inline-flex min-h-11 items-center gap-1.5 text-[12.5px] font-semibold text-ink-600 no-underline hover:text-ink-900 sm:min-h-9"
        >
          <.icon name="hero-paper-airplane" class="size-4" /> Prefiro pelo WhatsApp
        </a>

        <button
          :if={sent?(@receipt)}
          type="button"
          phx-click="remove_receipt"
          phx-value-id={@receipt.enrollment_id}
          data-confirm="Tirar o comprovante do ar?"
          class="inline-flex min-h-11 cursor-pointer items-center border-0 bg-transparent p-0 text-[12.5px] text-ink-500 underline sm:min-h-9"
        >
          Remover
        </button>
      </div>
    </div>
    """
  end

  defp sent?(%{sent_at: %DateTime{}}), do: true
  defp sent?(_none), do: false

  defp choose_label(receipt) do
    if sent?(receipt), do: "Trocar comprovante", else: "Escolher comprovante"
  end

  # Errors of the entry and errors of the upload itself (too many files) come from
  # different places and read the same to whoever is sending.
  defp receipt_errors(upload) do
    entry_errors = Enum.flat_map(upload.entries, &upload_errors(upload, &1))

    upload_errors(upload) ++ entry_errors
  end

  @doc false
  def receipt_upload_error(:too_large), do: "Arquivo grande demais. O limite é 10 MB."
  def receipt_upload_error(:not_accepted), do: "Só imagem (JPG, PNG, WEBP) ou PDF."
  def receipt_upload_error(:too_many_files), do: "Um comprovante por vez."
  def receipt_upload_error(_other), do: "Não deu para carregar esse arquivo."

  attr :media, :list, required: true
  attr :current_user, :map, default: nil
  attr :can_delete_any, :boolean, default: false

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

        <%!-- Enquanto o ffmpeg roda o arquivo ainda é o HEVC do celular, que
        em boa parte dos Android dá tela preta. Melhor dizer que está
        processando do que entregar um player que não toca. --%>
        <div
          :if={processando?(item)}
          class="flex aspect-square w-full flex-col items-center justify-center gap-2 bg-ink-100 text-ink-500"
        >
          <.icon name="hero-arrow-path" class="size-5 animate-spin text-ink-400" />
          <span class="text-[11px] font-medium">Processando vídeo</span>
        </div>

        <video
          :if={pronto?(item)}
          src={~p"/workshop-media/#{item.id}"}
          poster={poster_url(item)}
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

        <%!-- Always visible, never on hover: a phone has no hover, so the trash
        used to be an invisible button that still answered a tap. The `after`
        block takes the touch target to 44px without growing the circle. --%>
        <button
          :if={can_delete?(item, @current_user, @can_delete_any)}
          type="button"
          phx-click="remove_media"
          phx-value-id={item.id}
          data-confirm="Tirar esta mídia da galeria?"
          aria-label="Tirar da galeria"
          class="absolute right-2 top-2 inline-grid size-8 cursor-pointer place-items-center rounded-full border-0 bg-ink-900/70 text-ink-50 backdrop-blur-sm transition-colors after:absolute after:left-1/2 after:top-1/2 after:size-11 after:-translate-x-1/2 after:-translate-y-1/2 after:content-[''] hover:bg-ink-900"
        >
          <.icon name="hero-trash" class="size-4" />
        </button>

        <figcaption class="flex items-center gap-1.5 px-2 py-1.5 text-[11px] text-ink-500">
          <span class="truncate">{media_author(item)}</span>
        </figcaption>
      </figure>
    </div>
    """
  end

  defp processando?(%{kind: :video, status: :processing}), do: true
  defp processando?(_other), do: false

  defp pronto?(%{kind: :video, status: :ready}), do: true
  defp pronto?(_other), do: false

  # nil becomes an absent attribute in HEEx: `poster=""` would make the browser
  # request the page itself as an image.
  defp poster_url(%{poster_key: nil}), do: nil
  defp poster_url(%{id: id}), do: ~p"/workshop-media/#{id}/poster"

  defp can_delete?(_item, nil, _admin?), do: false
  defp can_delete?(_item, _user, true), do: true
  defp can_delete?(item, user, _admin?), do: item.uploaded_by_id == user.id

  defp media_author(%{uploaded_by: %{name: name, username: username}}), do: name || username
  defp media_author(_item), do: "Alguém do workshop"

  attr :program, :map, required: true
  attr :avulso_total, :integer, required: true
  attr :ja_comprou, :boolean, default: false
  attr :indisponivel, :string, default: nil
  attr :selecionaveis, :boolean, default: false

  @doc """
  The closed package, priced on the page instead of boxed off from it.

  It used to be a card with a green rail, paired against a dashed card that held
  nothing but the instructions for the other way in. Two boxes of the same size
  said the two paths weighed the same; they do not. Here the price is a line of
  the page and the day-by-day way is the sentence right under it.
  """
  def package_offer(assigns) do
    ~H"""
    <div class="mt-7 border-y border-ink-200 py-5">
      <div class="flex flex-wrap items-end justify-between gap-x-8 gap-y-4">
        <div class="min-w-0 flex-1 basis-[20rem]">
          <p class="brand-display is-title m-0 text-[27px] font-semibold leading-none tracking-tight text-ink-900">
            {money_label(@program.price_cents)}
            <span class="font-serif text-[13.5px] font-normal text-ink-500">
              pela programação toda
            </span>
          </p>

          <p class="m-0 mt-2 max-w-[38rem] font-sans text-[12.5px] leading-relaxed text-ink-500">
            <span :if={economia(@program, @avulso_total) > 0}>
              Sai
              <b class="font-semibold text-ink-700">
                {money_label(economia(@program, @avulso_total))}
              </b>
              mais barato do que pagar dia a dia.
            </span>
            <span :if={!@ja_comprou && @selecionaveis}>
              Se preferir, marque abaixo só os dias que te interessam.
            </span>
          </p>
        </div>

        <button
          :if={!@ja_comprou && is_nil(@indisponivel)}
          type="button"
          phx-click="buy_package"
          phx-disable-with="Confirmando..."
          class="w-full shrink-0 cursor-pointer rounded-full border-0 bg-accent-orange px-6 py-3 font-serif text-[15px] font-semibold text-white transition-colors hover:bg-accent-orange/90 sm:w-auto"
        >
          Quero a programação toda
        </button>

        <p
          :if={!@ja_comprou && @indisponivel}
          class="m-0 shrink-0 font-sans text-[12.5px] text-ink-500"
        >
          {@indisponivel}
        </p>

        <p
          :if={@ja_comprou}
          class="m-0 flex shrink-0 items-center gap-1.5 font-sans text-[13px] font-semibold text-ink-700"
        >
          <.icon name="hero-check-circle-solid" class="size-4 text-accent-green" />
          Você tem a programação toda
        </p>
      </div>

      <%!-- Chave Pix costuma ser CPF ou telefone: só depois de garantir a
      vaga, mesma regra da página do workshop. --%>
      <p
        :if={@program.payment_info && @ja_comprou}
        class="m-0 mt-3 font-sans text-[12.5px] leading-snug text-ink-500"
      >
        {@program.payment_info}
      </p>
    </div>
    """
  end

  @doc "How much the package saves against the sum of the single prices. Zero when it does not."
  def economia(%{price_cents: pacote}, avulso_total)
      when is_integer(pacote) and is_integer(avulso_total) and avulso_total > pacote,
      do: avulso_total - pacote

  def economia(_program, _avulso_total), do: 0

  attr :upload, :any, required: true
  attr :current_path, :string, default: nil
  attr :caption, :string, default: "Cartaz de divulgação, o mesmo que você manda no WhatsApp."

  def flyer_field(assigns) do
    ~H"""
    <div class="mt-4">
      <p class="mb-1 text-[12.5px] font-bold text-ink-700">
        Flyer <span class="font-normal text-ink-400">(opcional)</span>
      </p>
      <p class="m-0 mb-2 text-[12px] leading-snug text-ink-500">{@caption}</p>

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

      <%!-- Label no lugar do controle nativo: o texto do input de arquivo vem
      do navegador e sai em inglês ("Choose File", "No file chosen"). O input
      fica em sr-only, não display:none, para o teclado ainda alcançar. --%>
      <label
        for={@upload.ref}
        class="inline-flex cursor-pointer items-center gap-2 rounded-full bg-ink-900 px-4 py-2 font-serif text-[12.5px] font-semibold text-ink-50"
      >
        <.icon name="hero-arrow-up-tray" class="size-4" /> Escolher imagem
      </label>
      <.live_file_input upload={@upload} class="sr-only" />

      <div :for={entry <- @upload.entries} class="mt-2 flex items-center gap-3">
        <.live_img_preview
          entry={entry}
          class="h-24 w-auto rounded-lg border border-ink-200 object-cover"
        />
        <span class="text-[12px] text-ink-500">{entry.progress}%</span>
      </div>

      <div :for={entry <- @upload.entries}>
        <p
          :for={error <- upload_errors(@upload, entry)}
          class="m-0 mt-1 text-[12px] font-semibold text-accent-red"
        >
          {upload_error(error)}
        </p>
      </div>
    </div>
    """
  end

  @doc false
  def upload_error(:too_large), do: "Imagem grande demais. O limite é 8 MB."
  def upload_error(:not_accepted), do: "Formato não aceito. Use JPG, PNG ou WEBP."
  def upload_error(:too_many_files), do: "Só um flyer por vez."
  def upload_error(_other), do: "Não deu para carregar essa imagem."

  @doc """
  For instance `sábado, 16 de agosto · 14h às 18h`, or `16 a 18 de agosto ·
  começa 14h` when the workshop spans days.

  What decides between one day and several is the local calendar: an event running
  from 20h to 23h local time crosses midnight in UTC and is still a single night.
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

  # Across days what matters is until when it runs, not the closing hour of the
  # last day: "12 a 13 de setembro · 14h às 18h" would read as two things.
  defp multi_day(start_local, end_local) do
    "#{day_span(start_local, end_local)} · começa #{local_hour(start_local)}"
  end

  defp day_span(%{month: m} = start_local, %{month: m} = end_local),
    do: "#{start_local.day} a #{Brazil.strftime(end_local, "%d de %B")}"

  defp day_span(start_local, end_local),
    do: "#{month_day(start_local)} a #{month_day(end_local)}"

  defp month_day(local), do: Brazil.strftime(local, "%d de %B")

  @doc "For instance 14h às 18h (or just 14h when there is no end)."
  def time_range(%{starts_at: starts_at, ends_at: nil}), do: hour_label(starts_at)

  def time_range(%{starts_at: starts_at, ends_at: ends_at}),
    do: "#{hour_label(starts_at)} às #{hour_label(ends_at)}"

  @doc "Formatted price, or the free label."
  def price_label(%{price_cents: nil}), do: "Gratuito"
  def price_label(%{price_cents: 0}), do: "Gratuito"
  def price_label(%{price_cents: cents}), do: money_label(cents)

  @doc """
  Amount in reais. Unlike `price_label/1`, zero here is a number: on the organizer
  panel "R$ 0 recebido" is what happened, "Gratuito" is not.
  """
  def money_label(cents) when is_integer(cents), do: reais_label(div(cents, 100), rem(cents, 100))

  defp reais_label(reais, 0), do: "R$ #{reais}"

  defp reais_label(reais, centavos),
    do: "R$ #{reais},#{String.pad_leading(to_string(centavos), 2, "0")}"

  @doc """
  Summary of a program: how many workshops and on which days.

  For instance `2 workshops · 14 e 15 de agosto`, `15 workshops · 12 a 18 de fevereiro`.
  """
  def program_span([], _count), do: "Nenhum workshop ainda"

  def program_span(days, count) do
    datas = Enum.map(days, fn {date, _} -> date end)
    "#{workshop_count_label(count)} · #{date_span(List.first(datas), List.last(datas))}"
  end

  defp workshop_count_label(1), do: "1 workshop"
  defp workshop_count_label(count), do: "#{count} workshops"

  defp date_span(date, date), do: Brazil.strftime(date, "%d de %B")

  # Within a month the month is named once: "07 e 08 de agosto", "12 a 18 de
  # fevereiro". The day always takes two digits, as everywhere else in the app.
  defp date_span(%{month: m, year: y} = inicio, %{month: m, year: y} = fim) do
    "#{Brazil.strftime(inicio, "%d")} #{juntor(inicio, fim)} #{Brazil.strftime(fim, "%d de %B")}"
  end

  defp date_span(inicio, fim) do
    "#{Brazil.strftime(inicio, "%d de %B")} a #{Brazil.strftime(fim, "%d de %B")}"
  end

  defp juntor(inicio, fim) do
    if Date.diff(fim, inicio) == 1, do: "e", else: "a"
  end

  @doc "Like button label: the number disappears when nobody liked it yet."
  def like_label(true, 1), do: "Você curtiu"
  def like_label(true, count), do: "Você e mais #{count - 1}"
  def like_label(false, 0), do: "Curtir"
  def like_label(false, count), do: "Curtir · #{count}"

  @doc "Ex.: 1 inscrito / 32 inscritos"
  def people_label(1), do: "1 inscrito"
  def people_label(count), do: "#{count} inscritos"

  @doc "Payment state label (visible only to the organizer)."
  def payment_status_label(:paid), do: "Pago"
  def payment_status_label(:waived), do: "Isento"
  def payment_status_label(_status), do: "Aguardando"

  @doc "Percentual de vagas preenchidas, limitado a 100."
  def seats_percent(_enrolled, nil), do: 0
  def seats_percent(_enrolled, 0), do: 100

  def seats_percent(enrolled, capacity) do
    enrolled |> Kernel./(capacity) |> Kernel.*(100) |> round() |> min(100)
  end

  @doc """
  How to pay. The Pix key is usually the organizer's CPF or phone number, so it
  only shows for whoever enrolled (`reveal?`); everyone else sees the price and
  the instruction.
  """
  def payment_hint(workshop, reveal? \\ true)

  # When to pay is a choice; the Pix key, when there is one, comes after it.
  def payment_hint(%{payment_mode: modo} = workshop, true) when not is_nil(modo),
    do: [when_label(modo), pix_key(workshop)] |> Enum.reject(&is_nil/1) |> Enum.join(" ")

  def payment_hint(%{payment_info: info}, true) when is_binary(info) and info != "", do: info

  def payment_hint(%{organizer: %{name: name}}, _reveal?),
    do: "O pagamento é combinado direto com #{first_name(name)}."

  def payment_hint(_workshop, _reveal?), do: "O pagamento é combinado direto com quem organiza."

  defp when_label(:on_signup), do: "Pagamento na inscrição."
  defp when_label(:at_event), do: "Você paga na hora do evento."

  defp pix_key(%{payment_info: info}) when is_binary(info) and info != "", do: info
  defp pix_key(_workshop), do: nil

  defp first_name(nil), do: "quem organiza"
  defp first_name(name), do: name |> String.split(" ") |> List.first()

  # A workshop knows how to say where it is from its own parts; a program still
  # only has the free line.
  defp location_suffix(%Workshop{} = workshop) do
    case Workshop.place_line(workshop) do
      nil -> ""
      line -> " · #{line}"
    end
  end

  defp location_suffix(%{location: nil}), do: ""
  defp location_suffix(%{location: ""}), do: ""
  defp location_suffix(%{location: location}), do: " · #{location}"

  defp hour_label(datetime), do: local_hour(Brazil.to_local(datetime))

  defp local_hour(%{minute: 0} = local), do: "#{local.hour}h"

  defp local_hour(local),
    do: "#{local.hour}h#{String.pad_leading(to_string(local.minute), 2, "0")}"

  attr :enrolled_count, :integer, required: true
  attr :comment_count, :integer, default: 0

  @doc """
  What whoever stands outside sees in place of the inside.

  It shows the blurred shape and a readable count: hiding it would say "there is
  nothing here", and showing it in full would give away what only enrolled people
  paid for.
  """
  def locked_preview(assigns) do
    ~H"""
    <section class="mt-8 border-t border-ink-200 pt-6">
      <h2 class="brand-display is-title m-0 mb-4 flex items-center gap-2 text-[16px] font-semibold tracking-tight text-ink-800">
        <.icon name="hero-lock-closed" class="size-4 text-ink-500" /> Só para quem está na turma
      </h2>

      <.locked_row title="Quem vai" caption={people_caption(@enrolled_count)}>
        <span :for={_ <- 1..min(max(@enrolled_count, 1), 6)} class="-ml-2 first:ml-0">
          <span class="block size-7 rounded-full border-2 border-ink-100 bg-ink-300"></span>
        </span>
      </.locked_row>

      <.locked_row title="Fotos e vídeos" caption="Mandadas por quem está no workshop.">
        <span :for={_ <- 1..4} class="mr-1.5">
          <span class="block size-11 rounded-lg bg-ink-300"></span>
        </span>
      </.locked_row>

      <.locked_row title="Conversa" caption={conversation_caption(@comment_count)}>
        <span class="block w-full">
          <span class="mb-1.5 block h-2 w-3/4 rounded-full bg-ink-300"></span>
          <span class="mb-1.5 block h-2 w-1/2 rounded-full bg-ink-300"></span>
          <span class="block h-2 w-2/3 rounded-full bg-ink-300"></span>
        </span>
      </.locked_row>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :caption, :string, required: true
  slot :inner_block, required: true

  # Three dashed boxes said "three locked things" three times over. A hairline
  # between them says the same and lets the blurred shape do the talking.
  defp locked_row(assigns) do
    ~H"""
    <div class="border-t border-ink-200 py-3.5 first:border-t-0 first:pt-0">
      <p class="m-0 mb-2 font-sans text-[12px] font-semibold text-ink-700">{@title}</p>
      <div class="pointer-events-none flex select-none items-center opacity-45 blur-[4px]">
        {render_slot(@inner_block)}
      </div>
      <p class="m-0 mt-2 font-sans text-[12.5px] text-ink-500">{@caption}</p>
    </div>
    """
  end

  defp people_caption(0), do: "Ninguém confirmado ainda. Você pode ser a primeira pessoa."
  defp people_caption(1), do: "1 pessoa confirmada. O nome aparece quando você entrar."

  defp people_caption(total),
    do: "#{total} pessoas confirmadas. Os nomes aparecem quando você entrar."

  defp conversation_caption(0), do: "Ninguém comentou ainda."
  defp conversation_caption(1), do: "1 comentário."
  defp conversation_caption(total), do: "#{total} comentários."

  @doc """
  Whether the box should offer "ask to join".

  Only on a published private workshop, for whoever does not organize it, is not
  in the class and has no pending request.
  """
  def can_ask_to_join?(workshop, organizer?, enrolled?, status, full?)

  def can_ask_to_join?(
        %Workshop{visibility: :private, status: :published},
        false,
        false,
        status,
        false
      )
      when status in [:none, :rejected],
      do: true

  def can_ask_to_join?(_workshop, _organizer?, _enrolled?, _status, _full?), do: false

  @doc """
  Whether the box should offer the waitlist.

  Only on a full class with automatic enrollment: where the organizer approves
  each person, the extra seat is their call and there is no queue to form.
  """
  def shows_waitlist?(workshop, organizer?, enrolled?, full?, waitlist_entry)

  def shows_waitlist?(%Workshop{visibility: :public}, false, false, true, nil), do: true
  def shows_waitlist?(_workshop, _organizer?, _enrolled?, _full?, _waitlist_entry), do: false

  @doc "For instance 1 pessoa na espera / 4 pessoas na espera"
  def waitlist_label(1), do: "1 pessoa na espera"
  def waitlist_label(total), do: "#{total} pessoas na espera"

  @doc """
  Names of whoever teaches, on a single line.

  Two teachers is the common case (almost always a couple), so the "e" between
  them is the form that reads naturally.
  """
  def teacher_names([]), do: "quem organiza"
  def teacher_names([um]), do: um.name || um.username

  def teacher_names([first, segundo | _resto]),
    do: "#{first.name || first.username} e #{segundo.name || segundo.username}"
end
