defmodule OGrupoDeEstudosWeb.WorkshopsLive do
  @moduledoc """
  Agenda de workshops da comunidade (aba Workshops de /study).

  Mora numa LiveView própria em vez de virar mais uma aba de estado dentro
  da StudyLive: a agenda tem URL, filtros e busca próprios, e a StudyLive já
  carrega bastante coisa.
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

  # Pattern matching em vez de String.to_existing_atom: em dev o módulo de
  # query pode nem ter sido carregado ainda, e aí o atom não existe.
  defp period_atom("week"), do: :week
  defp period_atom("month"), do: :month
  defp period_atom("year"), do: :year
  defp period_atom("past"), do: :past
  defp period_atom(_upcoming), do: :upcoming

  @doc "Ex.: 3 workshops · 1 programação"
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

  # Conta o que a tela realmente renderiza: a secao "Voce organiza" mostra
  # workshops que o colapso tirou da agenda, e sem eles o card perdia o numero
  # de inscritos e a tag de esgotado.
  defp contagens(itens, meus) do
    (ids_de_workshop(itens) ++ Enum.map(meus, & &1.id))
    |> Enum.uniq()
    |> Workshops.enrollment_counts()
  end

  # Quem se inscreveu num workshop que foi colapsado precisa ver isso em algum
  # lugar: senao o card da programacao nao diz nada e parece que a inscricao
  # sumiu. Em lote, senao seria uma consulta por programacao.
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
