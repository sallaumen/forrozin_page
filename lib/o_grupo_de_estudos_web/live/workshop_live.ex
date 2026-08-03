defmodule OGrupoDeEstudosWeb.WorkshopLive do
  @moduledoc """
  Página pública do workshop: o link que circula no WhatsApp.

  Abre para quem ainda não tem conta (título, data, local, preço, descrição
  e quantas pessoas vão). Nomes dos inscritos e a inscrição em si exigem
  login. Nada de pagamento entra nesta LiveView — nem no socket.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Workshops}
  alias OGrupoDeEstudos.Workshops.Workshop

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.WorkshopComponents

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Workshops.get_by_slug(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Workshop não encontrado.")
         |> redirect(to: ~p"/study/workshops")}

      workshop ->
        {:ok, socket |> assign_workshop(workshop) |> assign(:page_title, workshop.title)}
    end
  end

  @impl true
  def handle_event("enroll", _params, %{assigns: %{current_user: nil}} = socket) do
    # Sem conta: guarda para onde voltar e manda para o cadastro.
    {:noreply, redirect(socket, to: ~p"/signup?#{[workshop: socket.assigns.workshop.slug]}")}
  end

  def handle_event("enroll", _params, socket) do
    user = socket.assigns.current_user

    case Workshops.enroll(socket.assigns.workshop, user) do
      {:ok, _enrollment} ->
        {:noreply,
         socket
         |> reload_workshop()
         |> put_flash(:info, "Inscrição confirmada! Te vejo lá.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, enroll_error(reason))}
    end
  end

  def handle_event("cancel_enrollment", _params, %{assigns: %{current_user: nil}} = socket),
    do: {:noreply, socket}

  def handle_event("cancel_enrollment", _params, socket) do
    case Workshops.cancel_enrollment(socket.assigns.workshop, socket.assigns.current_user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> reload_workshop()
         |> put_flash(:info, "Inscrição cancelada.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Você não estava inscrito.")}
    end
  end

  defp assign_workshop(socket, workshop) do
    user = socket.assigns[:current_user]
    participants = Workshops.list_participants(workshop.id)

    socket
    |> assign(:workshop, workshop)
    |> assign(:is_admin, user && Accounts.admin?(user))
    |> assign(:participants, participants)
    |> assign(:enrolled_count, length(participants))
    |> assign(:enrolled?, user && Enum.any?(participants, &(&1.user_id == user.id)))
    |> assign(:organizer?, user && workshop.organizer_id == user.id)
    |> assign(:full?, Workshop.full?(workshop, length(participants)))
  end

  defp reload_workshop(socket) do
    assign_workshop(socket, Workshops.get_by_slug(socket.assigns.workshop.slug))
  end

  defp enroll_error(:organizer), do: "Você organiza este workshop, já está dentro."
  defp enroll_error(:full), do: "As vagas acabaram."
  defp enroll_error(:not_open), do: "Este workshop não está aberto para inscrição."
  defp enroll_error(:already_enrolled), do: "Você já está inscrito."
end
