defmodule OGrupoDeEstudosWeb.UI.OnboardingBanner do
  @moduledoc """
  Light onboarding banner for first-time users.
  Shows once, dismissible via localStorage. No JS hook needed.
  """

  use Phoenix.Component
  use OGrupoDeEstudosWeb, :verified_routes

  def onboarding_banner(assigns) do
    ~H"""
    <div id="onboarding-banner" style="display:none;">
      <div class="bg-ink-900 border-b border-gold-500/20 px-4 py-3">
        <div class="max-w-4xl mx-auto flex items-center gap-4">
          <div class="flex-1 min-w-0">
            <p class="text-sm text-ink-100 font-serif">
              <span class="text-gold-500 font-bold">Bem-vindo ao Grupo de Estudos!</span>
              Uma wiki de forró roots construída pela comunidade.
            </p>
            <p class="text-xs text-ink-400 mt-0.5 font-sans">
              Explore passos, descubra conexões no mapa e contribua com a comunidade.
            </p>
          </div>
          <a href="/about"
            class="text-xs font-medium text-gold-500 bg-gold-500/10 border border-gold-500/30 rounded-full py-1.5 px-4 no-underline hover:bg-gold-500/20 flex-shrink-0 font-sans">
            Como funciona
          </a>
          <button
            onclick="document.getElementById('onboarding-banner').style.display='none';localStorage.setItem('onboarding_seen','1')"
            class="text-ink-500 hover:text-ink-300 bg-transparent border-0 cursor-pointer text-base p-1 flex-shrink-0 leading-none"
          >
            ✕
          </button>
        </div>
      </div>
    </div>
    <script>
      if(!localStorage.getItem('onboarding_seen')){
        document.getElementById('onboarding-banner').style.display='block'
      }
    </script>
    """
  end
end
