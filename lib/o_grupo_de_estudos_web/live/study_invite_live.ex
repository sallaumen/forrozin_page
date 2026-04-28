defmodule OGrupoDeEstudosWeb.StudyInviteLive do
  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.Accounts
  alias OGrupoDeEstudos.Accounts.User
  alias OGrupoDeEstudos.Study

  on_mount {OGrupoDeEstudosWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Accounts.get_user_by_invite_slug(slug) do
      %User{} = teacher when teacher.is_teacher ->
        {:ok,
         assign(socket,
           page_title: "Convite de estudo",
           teacher: teacher
         )}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Professor não encontrado.")
         |> push_navigate(to: ~p"/collection")}
    end
  end

  @impl true
  def handle_event(
        "accept_invite",
        _,
        %{assigns: %{current_user: nil, teacher: teacher}} = socket
      ) do
    {:noreply, push_navigate(socket, to: ~p"/signup?teacher_invite=#{teacher.invite_slug}")}
  end

  def handle_event("accept_invite", _, socket) do
    teacher = socket.assigns.teacher

    case Study.accept_invite(socket.assigns.current_user, teacher.invite_slug) do
      {:ok, _link} ->
        {:noreply,
         socket
         |> put_flash(:info, "Pedido enviado! #{teacher.name || teacher.username} vai receber e aprovar seu pedido.")
         |> push_navigate(to: ~p"/users/#{teacher.username}")}

      {:error, :cannot_link_self} ->
        {:noreply, put_flash(socket, :error, "Você não pode ser aluno de si mesmo.")}

      {:error, :already_pending} ->
        {:noreply, put_flash(socket, :info, "Pedido já enviado. Aguarde a resposta do professor.")}

      {:error, :already_connected} ->
        {:noreply,
         socket
         |> put_flash(:info, "Vocês já estudam juntos!")
         |> push_navigate(to: ~p"/users/#{teacher.username}")}

      _ ->
        {:noreply, put_flash(socket, :error, "Não foi possível enviar o pedido agora. Tente novamente.")}
    end
  end
end
