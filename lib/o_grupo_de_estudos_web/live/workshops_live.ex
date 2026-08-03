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

    workshops =
      Workshops.list_feed(
        period: period_atom(socket.assigns.period),
        search: socket.assigns.search
      )

    socket
    |> assign(:workshops, workshops)
    |> assign(:enrollment_counts, Workshops.enrollment_counts(Enum.map(workshops, & &1.id)))
    |> assign(:enrolled_ids, Workshops.enrolled_workshop_ids(user.id))
    |> assign(:mine, Workshops.list_for_organizer(user.id))
  end
end
