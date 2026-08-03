defmodule OGrupoDeEstudosWeb.WorkshopManageLive do
  @moduledoc """
  Painel do organizador: lista de inscritos e controle de pagamento.

  Vive em rota própria de propósito. A privacidade do pagamento é garantida
  pela topologia: este processo só existe para o organizador, e o dado nunca
  entra no socket da página pública.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Workshops}
  alias OGrupoDeEstudos.Authorization.Policy
  alias OGrupoDeEstudos.Workshops.Workshop

  on_mount {OGrupoDeEstudosWeb.Navigation, :primary}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  use OGrupoDeEstudosWeb.NotificationHandlers

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.WorkshopComponents

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    workshop = Workshops.get_by_slug(slug)
    user = socket.assigns.current_user

    if workshop && Policy.authorized?(:manage_workshop, user, workshop) do
      {:ok,
       socket
       |> assign(:page_title, "Gerenciar: #{workshop.title}")
       |> assign(:is_admin, Accounts.admin?(user))
       |> assign(:workshop, workshop)
       |> assign(:cobra?, !Workshop.free?(workshop))
       |> load_enrollments()}
    else
      {:ok,
       socket
       |> put_flash(:error, "Workshop não encontrado.")
       |> redirect(to: ~p"/study/workshops")}
    end
  end

  @impl true
  def handle_event("set_payment", %{"id" => enrollment_id, "status" => status}, socket)
      when status in ~w(pending paid waived) do
    user = socket.assigns.current_user
    workshop = socket.assigns.workshop

    case Workshops.set_payment_status(workshop, user, enrollment_id, payment_atom(status)) do
      {:ok, _} ->
        {:noreply, socket |> load_enrollments() |> put_flash(:info, payment_message(status))}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Inscrição não encontrada.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível atualizar o pagamento.")}
    end
  end

  def handle_event("set_payment", _params, socket), do: {:noreply, socket}

  def handle_event("publish", _params, socket) do
    user = socket.assigns.current_user

    case Workshops.publish_workshop(user, socket.assigns.workshop) do
      {:ok, workshop} ->
        {:noreply,
         socket
         |> assign(:workshop, workshop)
         |> put_flash(:info, "Workshop publicado! Agora é só compartilhar o link.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível publicar.")}
    end
  end

  def handle_event("cancel_workshop", _params, socket) do
    user = socket.assigns.current_user

    case Workshops.cancel_workshop(user, socket.assigns.workshop) do
      {:ok, workshop} ->
        {:noreply,
         socket
         |> assign(:workshop, workshop)
         |> put_flash(:info, "Workshop cancelado. Os inscritos continuam registrados.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível cancelar.")}
    end
  end

  def handle_event("copy_link", _params, socket) do
    url = OGrupoDeEstudosWeb.Endpoint.url() <> "/workshops/" <> socket.assigns.workshop.slug

    {:noreply,
     socket
     |> push_event("clipboard:copy", %{text: url})
     |> put_flash(:info, "Link copiado! Agora é só mandar para a turma.")}
  end

  defp load_enrollments(socket) do
    workshop = socket.assigns.workshop
    user = socket.assigns.current_user

    {:ok, enrollments} = Workshops.list_enrollments_for_organizer(workshop, user)
    {:ok, summary} = Workshops.payment_summary(workshop, user)

    socket
    |> assign(:enrollments, enrollments)
    |> assign(:summary, summary)
  end

  defp payment_atom("paid"), do: :paid
  defp payment_atom("waived"), do: :waived
  defp payment_atom(_pending), do: :pending

  defp payment_message("paid"), do: "Pagamento registrado."
  defp payment_message("waived"), do: "Marcado como isento."
  defp payment_message(_status), do: "Voltou para aguardando."

  @doc false
  def revenue_label(%{paid: paid}, %{price_cents: cents}) when is_integer(cents) and cents > 0 do
    money_label(paid * cents)
  end

  def revenue_label(_summary, _workshop), do: "—"
end
