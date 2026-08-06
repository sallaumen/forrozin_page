defmodule OGrupoDeEstudosWeb.WorkshopProgramManageLive do
  @moduledoc """
  Backstage of a program: the money, the packages, the assembly and the crew.

  It used to live at the bottom of the public program page, which is the link
  that goes to WhatsApp. A page a student reads should not carry the balance of
  the event under it, and the backstage only grew: it now has its own address.

  Whoever administers gets in, creator or invited co-organizer. Handing out that
  invitation stays with the creator alone.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Workshops}

  on_mount {OGrupoDeEstudosWeb.Navigation, :primary}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  use OGrupoDeEstudosWeb.NotificationHandlers

  import OGrupoDeEstudosWeb.UI.BottomNav
  import OGrupoDeEstudosWeb.UI.InlineEdit, only: [last_updated: 1]
  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.WorkshopComponents

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    program = Workshops.get_program_by_slug(slug)
    user = socket.assigns.current_user

    if program && Workshops.program_admin?(program, user) do
      {:ok, socket |> assign_base(program, user) |> load_backstage()}
    else
      {:ok,
       socket
       |> put_flash(:error, "Programação não encontrada.")
       |> redirect(to: ~p"/study/workshops")}
    end
  end

  defp assign_base(socket, program, user) do
    socket
    |> assign(:page_title, "Gerenciar: #{program.title}")
    |> assign(:program, program)
    |> assign(:is_admin, Accounts.admin?(user))
    |> assign(:creator?, program.owner_id == user.id)
    |> assign(:admin_form_error, nil)
  end

  defp load_backstage(socket) do
    program = socket.assigns.program
    user = socket.assigns.current_user
    {:ok, revenue} = Workshops.program_revenue(program, user)
    {:ok, pacotes} = Workshops.list_package_enrollments(program, user)
    {:ok, package_summary} = Workshops.package_summary(program, user)
    {:ok, package_shares} = Workshops.package_shares(program, user)

    socket
    |> assign(:revenue, revenue)
    |> assign(:pacotes, pacotes)
    |> assign(:package_summary, package_summary)
    |> assign(:package_shares, package_shares)
    |> assign(:tem_pacote?, Workshops.WorkshopProgram.pacote?(program))
    |> assign(:program_admins, Workshops.list_program_admins(program))
    |> assign_assembly(user)
  end

  defp assign_assembly(socket, user) do
    dentro = Workshops.list_program_workshops(socket.assigns.program, include_drafts: true)
    dentro_ids = MapSet.new(dentro, & &1.id)

    disponiveis =
      user.id
      |> Workshops.list_for_organizer()
      |> Enum.reject(&MapSet.member?(dentro_ids, &1.id))

    socket |> assign(:dentro, dentro) |> assign(:disponiveis, disponiveis)
  end

  @impl true
  def handle_event("set_package_payment", %{"id" => id, "status" => status}, socket)
      when status in ~w(pending paid waived) do
    program = socket.assigns.program
    user = socket.assigns.current_user

    case Workshops.set_package_payment(program, user, id, payment_atom(status)) do
      {:ok, _} ->
        {:noreply, socket |> load_backstage() |> put_flash(:info, "Pagamento atualizado.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível atualizar.")}
    end
  end

  def handle_event("set_package_payment", _params, socket), do: {:noreply, socket}

  def handle_event("attach_workshop", %{"id" => id}, socket) do
    program = socket.assigns.program

    case Workshops.attach_workshop(program, socket.assigns.current_user, id) do
      {:ok, _} -> {:noreply, load_backstage(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Não foi possível adicionar.")}
    end
  end

  def handle_event("detach_workshop", %{"id" => id}, socket) do
    program = socket.assigns.program

    case Workshops.detach_workshop(program, socket.assigns.current_user, id) do
      {:ok, _} -> {:noreply, load_backstage(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Não foi possível tirar.")}
    end
  end

  def handle_event("add_program_admin", %{"username" => username}, socket) do
    case Accounts.get_user_by_username(String.trim(username)) do
      nil -> {:noreply, assign(socket, :admin_form_error, "Não encontrei esse usuário.")}
      user -> {:noreply, promote(socket, user.id)}
    end
  end

  def handle_event("remove_program_admin", %{"id" => user_id}, socket) do
    program = socket.assigns.program

    case Workshops.remove_program_admin(program, socket.assigns.current_user, user_id) do
      {:ok, _} -> {:noreply, load_backstage(socket)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Não foi possível remover.")}
    end
  end

  defp promote(socket, user_id) do
    program = socket.assigns.program

    case Workshops.add_program_admin(program, socket.assigns.current_user, user_id) do
      {:ok, _} -> socket |> assign(:admin_form_error, nil) |> load_backstage()
      {:error, :already_admin} -> assign(socket, :admin_form_error, "Essa pessoa já administra.")
      {:error, _} -> assign(socket, :admin_form_error, "Não foi possível adicionar.")
    end
  end

  defp payment_atom("paid"), do: :paid
  defp payment_atom("waived"), do: :waived
  defp payment_atom(_pending), do: :pending
end
