defmodule ForrozinWeb.UserProfileLive do
  use ForrozinWeb, :live_view

  alias Forrozin.{Accounts, Encyclopedia, Engagement, Sequences}

  on_mount {ForrozinWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    case Accounts.get_user_by_username(username) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Usuário não encontrado.")
         |> redirect(to: ~p"/collection")}

      user ->
        steps = Encyclopedia.list_user_steps(user.id)
        sequences = Sequences.list_public_user_sequences(user.id)

        current_user = socket.assigns.current_user
        step_ids = Enum.map(steps, & &1.id)
        sequence_ids = Enum.map(sequences, & &1.id)

        step_likes = Engagement.likes_map(current_user.id, "step", step_ids)
        sequence_likes = Engagement.likes_map(current_user.id, "sequence", sequence_ids)

        {:ok,
         assign(socket,
           page_title: user.name || user.username,
           profile_user: user,
           user_steps: steps,
           user_sequences: sequences,
           step_likes: step_likes,
           sequence_likes: sequence_likes,
           is_own_profile: current_user.id == user.id,
           is_admin: Accounts.admin?(current_user)
         )}
    end
  end

  @impl true
  def handle_event("toggle_like", %{"type" => type, "id" => id}, socket) do
    current_user = socket.assigns.current_user

    case Engagement.toggle_like(current_user.id, type, id) do
      {:ok, _action} ->
        steps = socket.assigns.user_steps
        sequences = socket.assigns.user_sequences
        step_ids = Enum.map(steps, & &1.id)
        sequence_ids = Enum.map(sequences, & &1.id)

        step_likes = Engagement.likes_map(current_user.id, "step", step_ids)
        sequence_likes = Engagement.likes_map(current_user.id, "sequence", sequence_ids)

        {:noreply, assign(socket, step_likes: step_likes, sequence_likes: sequence_likes)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível registrar o like.")}
    end
  end
end
