defmodule OGrupoDeEstudosWeb.ForgotPasswordLive do
  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Esqueci minha senha", submitted: false)}
  end

  @impl true
  def handle_event("submit", %{"email" => email}, socket) do
    Accounts.request_password_reset(String.trim(email), OGrupoDeEstudosWeb.Endpoint)
    {:noreply, assign(socket, submitted: true)}
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
        <%!-- Left: branding --%>
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

        <%!-- Right: form --%>
        <div class="flex-1 flex items-center justify-center px-7 py-12 md:px-[72px] md:py-16">
          <div class="w-full max-w-[420px]">
            <h2 class="text-[28px] font-bold text-ink-900 tracking-[-0.5px] m-0 mb-2">
              Recuperar senha
            </h2>
            <p class="text-sm text-ink-500 mb-9">
              Enviaremos um link para criar uma senha nova.
            </p>

            <%= if @submitted do %>
              <div class="bg-accent-green/10 border border-accent-green/25 rounded-lg p-6">
                <p class="text-sm text-ink-700 leading-relaxed m-0">
                  Se esse email estiver cadastrado, você vai receber um link para redefinir sua senha. Confira sua caixa de entrada.
                </p>
                <.link
                  navigate="/login"
                  class="inline-block mt-4 text-sm font-bold text-accent-orange no-underline"
                >
                  Voltar para o login
                </.link>
              </div>
            <% else %>
              <form phx-submit="submit">
                <div class="mb-6">
                  <label class="block text-xs font-bold text-ink-700 uppercase tracking-wider mb-2">
                    Email
                  </label>
                  <input
                    type="email"
                    name="email"
                    required
                    autofocus
                    aria-label="Email"
                    placeholder="seu@email.com"
                    class="w-full py-3 px-4 border border-[rgba(180,120,40,0.35)] rounded bg-ink-50 text-ink-800 font-serif text-base box-border outline-none focus:ring-2 focus:ring-accent-orange/30"
                  />
                </div>
                <button
                  type="submit"
                  phx-disable-with="Enviando..."
                  aria-label="Enviar link de recuperação"
                  class="w-full py-3.5 bg-ink-900 text-ink-100 border-0 rounded font-serif text-base font-bold tracking-wide cursor-pointer hover:bg-ink-800 transition-colors"
                >
                  Enviar link
                </button>
              </form>
              <p class="text-center mt-5 text-sm text-ink-500">
                <.link navigate="/login" class="text-ink-500 no-underline hover:text-ink-700">
                  Voltar para o login
                </.link>
              </p>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
