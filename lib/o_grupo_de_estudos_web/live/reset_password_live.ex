defmodule OGrupoDeEstudosWeb.ResetPasswordLive do
  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.Accounts

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.verify_reset_token(OGrupoDeEstudosWeb.Endpoint, token) do
      {:ok, user} ->
        {:ok,
         assign(socket,
           page_title: "Nova senha",
           user: user,
           token: token,
           error: nil
         )}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Link expirado ou inválido. Pede outro.")
         |> redirect(to: "/forgot-password")}
    end
  end

  @impl true
  def handle_event("reset", %{"password" => password, "password_confirmation" => confirmation}, socket) do
    cond do
      String.length(password) < 8 ->
        {:noreply, assign(socket, error: "A senha precisa ter pelo menos 8 caracteres.")}

      password != confirmation ->
        {:noreply, assign(socket, error: "As senhas não batem.")}

      true ->
        case Accounts.reset_password(socket.assigns.user, password) do
          {:ok, _user} ->
            {:noreply,
             socket
             |> put_flash(:info, "Senha atualizada! Agora é só entrar.")
             |> redirect(to: "/login")}

          {:error, _changeset} ->
            {:noreply, assign(socket, error: "Erro ao atualizar a senha. Tenta de novo.")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-ink-100 font-serif flex items-center justify-center px-4">
      <div class="w-full max-w-md">
        <div class="text-center mb-8">
          <h1 class="text-2xl font-bold text-ink-900">Criar nova senha</h1>
        </div>

        <form phx-submit="reset" class="bg-ink-50 border border-ink-200 rounded-lg p-6">
          <%= if @error do %>
            <div class="mb-4 py-2 px-3 bg-accent-red/10 border border-accent-red/25 rounded text-sm text-accent-red">
              {@error}
            </div>
          <% end %>

          <div class="mb-4">
            <label class="block text-xs font-bold text-ink-700 uppercase tracking-wider mb-1">
              Nova senha
            </label>
            <input
              type="password"
              name="password"
              required
              autofocus
              minlength="8"
              placeholder="Mínimo 8 caracteres"
              class="w-full py-2.5 px-3 border border-ink-300 rounded-md font-serif text-sm text-ink-900 box-border focus:ring-2 focus:ring-accent-orange/30 outline-none"
            />
          </div>
          <div class="mb-4">
            <label class="block text-xs font-bold text-ink-700 uppercase tracking-wider mb-1">
              Confirmar senha
            </label>
            <input
              type="password"
              name="password_confirmation"
              required
              minlength="8"
              placeholder="Digita de novo"
              class="w-full py-2.5 px-3 border border-ink-300 rounded-md font-serif text-sm text-ink-900 box-border focus:ring-2 focus:ring-accent-orange/30 outline-none"
            />
          </div>
          <button
            type="submit"
            phx-disable-with="Salvando..."
            class="w-full py-3 bg-ink-900 text-ink-100 border-0 rounded-md font-serif text-sm font-bold tracking-wide cursor-pointer hover:bg-ink-800 transition-colors"
          >
            Salvar nova senha
          </button>
        </form>
      </div>
    </div>
    """
  end
end
