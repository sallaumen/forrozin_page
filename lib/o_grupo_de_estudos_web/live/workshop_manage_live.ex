defmodule OGrupoDeEstudosWeb.WorkshopManageLive do
  @moduledoc """
  Organizer panel: enrollment list and payment control.

  It lives on its own route on purpose. Payment privacy is guaranteed by the
  context, which only projects those fields in the organizer read.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Workshops}
  alias OGrupoDeEstudos.Authorization.Policy
  alias OGrupoDeEstudos.Workshops.Workshop

  on_mount {OGrupoDeEstudosWeb.Navigation, :primary}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  use OGrupoDeEstudosWeb.NotificationHandlers

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.UI.UserAvatar, only: [user_avatar: 1]
  import OGrupoDeEstudosWeb.WorkshopComponents

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    workshop = Workshops.get_by_slug(slug)
    user = socket.assigns.current_user

    if workshop &&
         Policy.authorized?(:manage_workshop, user, Workshops.access_for(workshop, user)) do
      {:ok,
       socket
       |> assign(:page_title, "Gerenciar: #{workshop.title}")
       |> assign(:is_admin, Accounts.admin?(user))
       |> assign(:workshop, workshop)
       |> assign(:owner?, workshop.organizer_id == user.id)
       |> assign(:cobra?, !Workshop.free?(workshop))
       |> assign(:admin_form_error, nil)
       |> load_enrollments()
       |> load_co_admins()
       |> load_requests()
       |> load_waitlist()}
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

  def handle_event("add_admin", %{"username" => username}, socket) do
    case Accounts.get_user_by_username(String.trim(username)) do
      nil -> {:noreply, assign(socket, :admin_form_error, "Não encontrei esse usuário.")}
      user -> promote(socket, user)
    end
  end

  def handle_event("remove_admin", %{"id" => user_id}, socket) do
    workshop = socket.assigns.workshop

    case Workshops.remove_admin(workshop, socket.assigns.current_user, user_id) do
      {:ok, _} ->
        {:noreply, socket |> load_co_admins() |> put_flash(:info, "Co-organizador removido.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível remover.")}
    end
  end

  def handle_event("approve_join", %{"id" => id}, socket) do
    socket.assigns.workshop
    |> Workshops.approve_join(socket.assigns.current_user, id)
    |> respond_to_request(socket, "Entrou na turma.")
  end

  def handle_event("reject_join", %{"id" => id}, socket) do
    socket.assigns.workshop
    |> Workshops.reject_join(socket.assigns.current_user, id)
    |> respond_to_request(socket, "Pedido recusado.")
  end

  def handle_event("copy_link", _params, socket) do
    url = OGrupoDeEstudosWeb.Endpoint.url() <> "/workshops/" <> socket.assigns.workshop.slug

    {:noreply,
     socket
     |> push_event("clipboard:copy", %{text: url})
     |> put_flash(:info, "Link copiado! Agora é só mandar para a turma.")}
  end

  defp promote(socket, user) do
    workshop = socket.assigns.workshop

    case Workshops.add_admin(workshop, socket.assigns.current_user, user.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:admin_form_error, nil)
         |> load_co_admins()
         |> put_flash(:info, "#{user.name || user.username} agora organiza com você.")
         |> push_event("form:clear", %{id: "add-admin-form"})}

      {:error, :already_admin} ->
        {:noreply, assign(socket, :admin_form_error, "Essa pessoa já organiza este workshop.")}

      {:error, _} ->
        {:noreply, assign(socket, :admin_form_error, "Não foi possível adicionar.")}
    end
  end

  defp respond_to_request({:ok, _request}, socket, mensagem) do
    {:noreply,
     socket
     |> load_requests()
     |> load_enrollments()
     |> put_flash(:info, mensagem)}
  end

  defp respond_to_request({:error, :full}, socket, _mensagem) do
    {:noreply, put_flash(socket, :error, "A turma está cheia. Abra uma vaga antes de aceitar.")}
  end

  defp respond_to_request({:error, _reason}, socket, _mensagem) do
    {:noreply, put_flash(socket, :error, "Não foi possível responder esse pedido.")}
  end

  defp load_waitlist(socket) do
    assign(socket, :waitlist, Workshops.list_waitlist(socket.assigns.workshop.id))
  end

  defp load_requests(socket) do
    assign(socket, :requests, Workshops.list_pending_requests(socket.assigns.workshop.id))
  end

  defp load_co_admins(socket) do
    assign(socket, :co_admins, Workshops.list_co_admins(socket.assigns.workshop))
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

  # The city helps the organizer recognize the person, but not everyone fills it
  # in: with no city the row simply does not mention it.
  defp request_city(%{city: city}) when is_binary(city) and city != "",
    do: " · #{city}"

  defp request_city(_request), do: ""
end
