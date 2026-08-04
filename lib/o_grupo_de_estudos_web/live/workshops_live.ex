defmodule OGrupoDeEstudosWeb.WorkshopsLive do
  @moduledoc """
  Community workshop agenda (the Workshops tab of /study).

  It lives in its own LiveView instead of becoming one more state tab inside the
  study page: it has its own URL, so the link can be shared.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Workshops}
  alias OGrupoDeEstudos.Authorization.Policy

  on_mount {OGrupoDeEstudosWeb.Navigation, :primary}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.UI.BottomNav
  import OGrupoDeEstudosWeb.StudyComponents
  import OGrupoDeEstudosWeb.WorkshopComponents

  use OGrupoDeEstudosWeb.NotificationHandlers

  @periods ~w(upcoming week month year past)

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:page_title, "Workshops")
     |> assign(:is_admin, Accounts.admin?(user))
     |> assign(:period, "upcoming")
     |> assign(:search, "")
     |> assign(:can_create, Policy.authorized?(:create_workshop, user, nil))
     |> load_feed()}
  end

  @impl true
  def handle_event("filter_period", %{"period" => period}, socket) when period in @periods do
    {:noreply, socket |> assign(:period, period) |> load_feed()}
  end

  def handle_event("filter_period", _params, socket), do: {:noreply, socket}

  def handle_event("search_workshops", %{"term" => term}, socket) do
    {:noreply, socket |> assign(:search, term) |> load_feed()}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply, socket |> assign(:search, "") |> load_feed()}
  end

  # Pattern matching instead of String.to_existing_atom: in dev the query module
  # may not have been loaded yet, and then the atom does not exist.
  defp period_atom("week"), do: :week
  defp period_atom("month"), do: :month
  defp period_atom("year"), do: :year
  defp period_atom("past"), do: :past
  defp period_atom(_upcoming), do: :upcoming

  @doc "For instance 3 workshops · 1 programação"
  def contagem_da_agenda(itens) do
    {programas, workshops} = Enum.split_with(itens, &(&1.kind == :program))

    [
      rotulo(length(workshops), "workshop", "workshops"),
      rotulo(length(programas), "programação", "programações")
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  defp rotulo(0, _singular, _plural), do: nil
  defp rotulo(1, singular, _plural), do: "1 #{singular}"
  defp rotulo(total, _singular, plural), do: "#{total} #{plural}"

  @doc false
  def period_heading("upcoming"), do: "Em breve"
  def period_heading("week"), do: "Esta semana"
  def period_heading("month"), do: "Este mês"
  def period_heading("year"), do: "Este ano"
  def period_heading("past"), do: "Já aconteceram"

  @doc false
  def empty_hint("past"), do: "Quando um workshop terminar, ele aparece aqui."
  def empty_hint(_period), do: "Que tal organizar o seu? Leva menos de um minuto."

  defp load_feed(socket) do
    user = socket.assigns.current_user

    itens =
      Workshops.list_agenda(
        period: period_atom(socket.assigns.period),
        search: socket.assigns.search
      )

    meus = Workshops.list_for_organizer(user.id)
    inscritos = Workshops.enrolled_workshop_ids(user.id)

    socket
    |> assign(:itens, marcar_inscricao(itens, user))
    |> assign(:enrollment_counts, contagens(itens, meus))
    |> assign(:enrolled_ids, inscritos)
    |> assign(:mine, meus)
    |> assign(:minhas_programacoes, Workshops.list_programs_for_owner(user.id))
  end

  # Counts what the screen actually renders: the "Você organiza" section shows
  # workshops the collapse took off the agenda, and without them the card lost the
  # enrolled count and the sold-out tag.
  defp contagens(itens, meus) do
    (ids_de_workshop(itens) ++ Enum.map(meus, & &1.id))
    |> Enum.uniq()
    |> Workshops.enrollment_counts()
  end

  # Whoever enrolled in a collapsed workshop needs to see it somewhere: otherwise
  # the program card says nothing and the enrollment looks lost. Batched, or it
  # would be one query per program.
  defp marcar_inscricao(itens, user) do
    contagens =
      itens
      |> Enum.filter(&(&1.kind == :program))
      |> Enum.map(& &1.program.id)
      |> then(&Workshops.enrolled_counts_by_program(user.id, &1))

    Enum.map(itens, &com_inscricao(&1, contagens))
  end

  defp com_inscricao(%{kind: :program} = item, contagens),
    do: Map.put(item, :enrolled_count, Map.get(contagens, item.program.id, 0))

  defp com_inscricao(item, _contagens), do: item

  defp ids_de_workshop(itens) do
    itens
    |> Enum.filter(&(&1.kind == :workshop))
    |> Enum.map(& &1.workshop.id)
  end
end
