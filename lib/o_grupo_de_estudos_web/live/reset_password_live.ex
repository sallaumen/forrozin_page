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
  def handle_event(
        "reset",
        %{"password" => password, "password_confirmation" => confirmation},
        socket
      ) do
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
    <div class="min-h-screen bg-ink-100 font-serif flex flex-col">
      <header class="bg-ink-900 px-6 py-3.5 flex items-center justify-between flex-shrink-0">
        <a
          href={~p"/"}
          class="font-serif text-[13px] font-bold tracking-widest text-ink-200 uppercase no-underline"
        >
          O Grupo de Estudos
        </a>
        <a href={~p"/login"} class="font-serif text-xs text-ink-400 no-underline tracking-wider">
          Entrar →
        </a>
      </header>

      <div class="flex-1 flex flex-col md:flex-row">
        <div class="hidden md:flex w-[42%] bg-ink-900 px-14 py-16 flex-col justify-center">
          <p class="text-[11px] font-bold tracking-[3px] uppercase text-ink-700 mb-7">
            O grupo de estudos
          </p>
          <h1 class="text-[36px] font-bold text-ink-200 leading-tight tracking-[-1px] m-0 mb-6">
            Uma wiki de forró construída pela comunidade.
          </h1>
          <p class="text-base leading-[1.9] text-ink-400 mb-0">
            Mais de 150 passos documentados, conexões entre eles, sequências e diário de treino. Tudo aberto e gratuito.
          </p>
        </div>

        <div class="flex-1 flex items-center justify-center px-7 py-12 md:px-[72px] md:py-16">
          <div class="w-full max-w-[420px]">
            <h2 class="text-[28px] font-bold text-ink-900 tracking-[-0.5px] m-0 mb-2">
              Criar nova senha
            </h2>
            <p class="text-sm text-ink-500 mb-9">
              Escolha uma senha nova para sua conta.
            </p>

            <form phx-submit="reset">
              <%= if @error do %>
                <div
                  role="alert"
                  class="mb-6 py-2.5 px-4 bg-accent-red/10 border border-accent-red/25 rounded text-sm text-accent-red"
                >
                  {@error}
                </div>
              <% end %>

              <div class="mb-5">
                <label class="block text-xs font-bold text-ink-700 uppercase tracking-wider mb-2">
                  Nova senha
                </label>
                <input
                  type="password"
                  name="password"
                  required
                  autofocus
                  minlength="8"
                  aria-label="Nova senha"
                  placeholder="Mínimo 8 caracteres"
                  class="w-full py-3 px-4 border border-[rgba(180,120,40,0.35)] rounded bg-ink-50 text-ink-800 font-serif text-base box-border outline-none focus:ring-2 focus:ring-accent-orange/30"
                />
              </div>
              <div class="mb-6">
                <label class="block text-xs font-bold text-ink-700 uppercase tracking-wider mb-2">
                  Confirmar senha
                </label>
                <input
                  type="password"
                  name="password_confirmation"
                  required
                  minlength="8"
                  aria-label="Confirmar senha"
                  placeholder="Digita de novo"
                  class="w-full py-3 px-4 border border-[rgba(180,120,40,0.35)] rounded bg-ink-50 text-ink-800 font-serif text-base box-border outline-none focus:ring-2 focus:ring-accent-orange/30"
                />
              </div>
              <button
                type="submit"
                phx-disable-with="Salvando..."
                aria-label="Salvar nova senha"
                class="w-full py-3.5 bg-ink-900 text-ink-100 border-0 rounded font-serif text-base font-bold tracking-wide cursor-pointer hover:bg-ink-800 transition-colors"
              >
                Salvar nova senha
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
