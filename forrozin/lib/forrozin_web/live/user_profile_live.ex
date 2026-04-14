defmodule ForrozinWeb.UserProfileLive do
  use ForrozinWeb, :live_view

  alias Forrozin.{Accounts, Encyclopedia}

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

        {:ok,
         assign(socket,
           page_title: user.name || user.username,
           profile_user: user,
           user_steps: steps,
           is_own_profile: socket.assigns.current_user.id == user.id
         )}
    end
  end
end
