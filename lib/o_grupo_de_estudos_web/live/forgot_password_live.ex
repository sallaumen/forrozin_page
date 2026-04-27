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
    <div class="min-h-screen bg-ink-100 font-serif flex items-center justify-center px-4">
      <div class="w-full max-w-md">
        <div class="text-center mb-8">
          <h1 class="text-2xl font-bold text-ink-900">Esqueci minha senha</h1>
        </div>

        <%= if @submitted do %>
          <div class="bg-accent-green/10 border border-accent-green/25 rounded-lg p-6 text-center">
            <p class="text-sm text-ink-700 leading-relaxed">
              Se esse email estiver cadastrado, você vai receber um link pra criar uma senha nova.
              Confere sua caixa de entrada (e o spam, vai que).
            </p>
            <.link
              navigate="/login"
              class="inline-block mt-4 text-sm font-bold text-accent-orange no-underline"
            >
              Voltar pro login
            </.link>
          </div>
        <% else %>
          <form phx-submit="submit" class="bg-ink-50 border border-ink-200 rounded-lg p-6">
            <p class="text-sm text-ink-600 mb-4 leading-relaxed">
              Digita o email que você usou pra se cadastrar. A gente manda um link pra você criar uma senha nova.
            </p>
            <div class="mb-4">
              <label class="block text-xs font-bold text-ink-700 uppercase tracking-wider mb-1">
                Email
              </label>
              <input
                type="email"
                name="email"
                required
                autofocus
                placeholder="seu@email.com"
                class="w-full py-2.5 px-3 border border-ink-300 rounded-md font-serif text-sm text-ink-900 box-border focus:ring-2 focus:ring-accent-orange/30 outline-none"
              />
            </div>
            <button
              type="submit"
              phx-disable-with="Enviando..."
              class="w-full py-3 bg-ink-900 text-ink-100 border-0 rounded-md font-serif text-sm font-bold tracking-wide cursor-pointer hover:bg-ink-800 transition-colors"
            >
              Enviar link de recuperação
            </button>
          </form>
          <div class="text-center mt-4">
            <.link navigate="/login" class="text-sm text-ink-500 no-underline hover:text-ink-700">
              Voltar pro login
            </.link>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
