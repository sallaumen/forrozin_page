defmodule OGrupoDeEstudosWeb.UI.PWAInstallBanner do
  @moduledoc """
  PWA install banner — elegant, on-brand bottom bar.
  Hidden in standalone mode (PWA). Dismissible per session.
  """

  use Phoenix.Component

  def pwa_install_banner(assigns) do
    ~H"""
    <div
      id="pwa-install-banner"
      phx-hook="PWAInstall"
      class="hidden fixed bottom-14 left-0 right-0 z-30 md:bottom-0"
    >
      <div class="bg-gold-500 px-4 py-2 flex items-center gap-3 shadow-lg">
        <img src="/icons/icon-192.png" alt="OGE"
          class="w-8 h-8 rounded-lg flex-shrink-0 border border-ink-900/20 shadow-sm" />
        <div class="flex-1 min-w-0">
          <p class="text-xs font-bold text-ink-900 font-serif leading-tight">
            O Grupo de Estudos na sua tela inicial
          </p>
          <p class="text-[10px] text-ink-900/70 font-sans leading-tight mt-0.5">
            Acesso rápido, como um app nativo
          </p>
        </div>
        <button
          id="pwa-install-btn"
          class="bg-ink-900 text-gold-500 text-xs font-bold py-1.5 px-4 rounded-full flex-shrink-0 cursor-pointer border-0 font-serif tracking-wide shadow-sm hover:bg-ink-800 transition-colors"
        >
          Instalar
        </button>
        <button
          id="pwa-dismiss-btn"
          class="text-ink-900/40 hover:text-ink-900/70 cursor-pointer bg-transparent border-0 p-1 flex-shrink-0 text-base leading-none"
        >
          ✕
        </button>
      </div>
    </div>
    """
  end
end
