defmodule OGrupoDeEstudosWeb.UI.PWAInstallBanner do
  @moduledoc """
  PWA install prompt banner — fixed above the bottom nav on mobile,
  fixed at the bottom on desktop. Hidden by default; revealed by the
  PWAInstall JS hook after the beforeinstallprompt event fires or after
  a short delay (iOS fallback).
  """

  use Phoenix.Component

  def pwa_install_banner(assigns) do
    ~H"""
    <div
      id="pwa-install-banner"
      phx-hook="PWAInstall"
      class="hidden fixed bottom-14 left-0 right-0 z-30 md:bottom-0"
    >
      <div class="bg-ink-900 text-ink-100 px-4 py-2.5 flex items-center gap-3 max-w-4xl mx-auto">
        <img src="/icons/icon-192.png" alt="OGE" class="w-6 h-6 rounded flex-shrink-0" />
        <span class="text-xs flex-1 font-sans">Instale como app</span>
        <button
          id="pwa-install-btn"
          class="bg-accent-orange text-white text-xs font-medium py-1 px-3 rounded-full flex-shrink-0 cursor-pointer border-0"
        >
          Instalar
        </button>
        <button
          id="pwa-dismiss-btn"
          class="text-ink-500 hover:text-ink-300 text-sm cursor-pointer bg-transparent border-0 p-1 flex-shrink-0"
        >
          ✕
        </button>
      </div>
    </div>
    """
  end
end
