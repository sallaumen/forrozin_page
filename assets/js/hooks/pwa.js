// ---------------------------------------------------------------------------
// Hook: PWAInstall — elegant install banner
// ---------------------------------------------------------------------------
const PWAInstall = {
  mounted() {
    const isStandalone = window.matchMedia('(display-mode: standalone)').matches
      || window.navigator.standalone === true

    // Hide completely in PWA mode
    if (isStandalone) {
      this.el.remove()
      return
    }

    // Show at most once per week (localStorage persists across sessions)
    const lastDismissed = localStorage.getItem('pwa_banner_dismissed_at')
    if (lastDismissed) {
      const weekMs = 7 * 24 * 60 * 60 * 1000
      if (Date.now() - parseInt(lastDismissed) < weekMs) return
    }

    const banner = this.el
    const installBtn = document.getElementById('pwa-install-btn')
    const dismissBtn = document.getElementById('pwa-dismiss-btn')

    // Show after 3s delay
    setTimeout(() => banner.classList.remove('hidden'), 3000)

    if (installBtn) {
      installBtn.addEventListener('click', async () => {
        if (window._deferredPWAPrompt) {
          // Chrome/Android: native install prompt
          window._deferredPWAPrompt.prompt()
          const { outcome } = await window._deferredPWAPrompt.userChoice
          if (outcome === 'accepted') {
            banner.classList.add('hidden')
            localStorage.setItem('pwa_banner_dismissed_at', Date.now().toString())
          }
          window._deferredPWAPrompt = null
        } else {
          // iOS/other: show a helpful modal instead of ugly alert
          showInstallInstructions()
        }
      })
    }

    if (dismissBtn) {
      dismissBtn.addEventListener('click', () => {
        banner.classList.add('hidden')
        localStorage.setItem('pwa_banner_dismissed_at', Date.now().toString())
      })
    }
  }
}

// All text content in this function is hardcoded (no user input), so innerHTML usage is safe.
function showInstallInstructions() {
  document.getElementById('pwa-instructions-modal')?.remove()

  const ua = navigator.userAgent
  const isIOS = /iPad|iPhone|iPod/.test(ua)
  const isSafari = isIOS && /Safari/.test(ua) && !/CriOS|FxiOS|OPiOS/.test(ua)
  const isChromeIOS = isIOS && /CriOS/.test(ua)
  const isSamsung = /SamsungBrowser/.test(ua)

  let title, steps, tip

  if (isSafari) {
    title = 'Como instalar no iPhone (Safari)'
    steps = '<li>Toque no botao <strong>Compartilhar</strong> na barra inferior do Safari'
      + '<div style="margin:6px 0 4px;font-size:28px;text-align:center;">'
      + '<span style="display:inline-block;border:2px solid #b47828;border-radius:8px;padding:2px 10px;">\u2B06</span>'
      + '</div></li>'
      + '<li>Role a lista para baixo ate encontrar <strong>"Adicionar a Tela de Inicio"</strong>'
      + '<div style="margin:4px 0;padding:6px 10px;background:#e8e0d4;border-radius:8px;font-size:12px;display:flex;align-items:center;gap:6px;">'
      + '<span style="font-size:16px;">\u2795</span> Adicionar a Tela de Inicio</div></li>'
      + '<li>Toque em <strong>"Adicionar"</strong> no canto superior direito</li>'
    tip = 'Precisa ser no Safari! Chrome e outros navegadores no iPhone nao tem essa opcao.'
  } else if (isChromeIOS) {
    title = 'Como instalar no iPhone'
    steps = '<li>Abra este site no <strong>Safari</strong> (nao no Chrome)</li>'
      + '<li>No Safari, toque em <strong>Compartilhar</strong> \u2B06</li>'
      + '<li>Selecione <strong>"Adicionar a Tela de Inicio"</strong></li>'
      + '<li>Toque em <strong>Adicionar</strong></li>'
    tip = 'No iPhone, so o Safari permite instalar apps na tela inicial. Copie o link e abra no Safari.'
  } else if (isSamsung) {
    title = 'Como instalar (Samsung Internet)'
    steps = '<li>Toque no menu <strong>\u2630</strong> (tres barras) no canto inferior</li>'
      + '<li>Selecione <strong>"Adicionar pagina a"</strong></li>'
      + '<li>Escolha <strong>"Tela inicial"</strong></li>'
    tip = null
  } else {
    title = 'Como instalar no celular'
    steps = '<li>Toque no menu <strong>\u22EE</strong> (tres pontinhos) no canto superior direito do navegador</li>'
      + '<li>Selecione <strong>"Instalar aplicativo"</strong> ou <strong>"Adicionar a tela inicial"</strong>'
      + '<div style="margin:4px 0;padding:6px 10px;background:#e8e0d4;border-radius:8px;font-size:12px;">'
      + '\uD83D\uDCF2 Instalar aplicativo</div></li>'
      + '<li>Confirme tocando em <strong>"Instalar"</strong></li>'
    tip = null
  }

  const tipHtml = tip
    ? '<div style="margin:12px 0 16px;padding:10px 12px;background:#fef3c7;border:1px solid #f59e0b40;border-radius:10px;text-align:left;">'
      + '<p style="margin:0;font-size:11px;color:#92400e;line-height:1.5;">'
      + '<strong>Dica:</strong> ' + tip + '</p></div>'
    : ''

  const modal = document.createElement('div')
  modal.id = 'pwa-instructions-modal'
  modal.style.cssText = 'position:fixed;inset:0;z-index:9999;display:flex;align-items:flex-end;justify-content:center;background:rgba(26,14,5,0.85);padding:0;'
  modal.innerHTML = '<div style="background:#f7f3ec;border-radius:20px 20px 0 0;padding:28px 24px max(24px,env(safe-area-inset-bottom));max-width:400px;width:100%;font-family:Georgia,serif;animation:slideUp 0.25s ease-out;">'
    + '<div style="width:36px;height:4px;background:#d4c8b8;border-radius:2px;margin:0 auto 20px;"></div>'
    + '<img src="/icons/icon-192.png" alt="OGE" style="width:48px;height:48px;border-radius:12px;margin:0 auto 12px;display:block;box-shadow:0 4px 12px rgba(0,0,0,0.15);" />'
    + '<h3 style="font-size:17px;color:#1a0e05;margin:0 0 4px;font-weight:700;text-align:center;">' + title + '</h3>'
    + '<p style="font-size:12px;color:#7a5c3a;margin:0 0 16px;line-height:1.5;text-align:center;">Vai ficar como um app de verdade na sua tela</p>'
    + '<ol style="text-align:left;font-size:13px;color:#3a2510;line-height:1.7;padding-left:20px;margin:0;">' + steps + '</ol>'
    + tipHtml
    + '<button onclick="this.closest(\'#pwa-instructions-modal\').remove()" style="display:block;width:100%;background:#1a0e05;color:#d4a574;border:none;padding:12px;border-radius:12px;font-family:Georgia,serif;font-size:14px;font-weight:700;cursor:pointer;letter-spacing:0.5px;margin-top:16px;">Entendi!</button>'
    + '</div>'
    + '<style>@keyframes slideUp{from{transform:translateY(100%)}to{transform:translateY(0)}}</style>'
  document.body.appendChild(modal)
  modal.addEventListener('click', (e) => {
    if (e.target === modal) modal.remove()
  })
}

// Hook: PWAInstallSettings — permanent install button in Settings page
const PWAInstallSettings = {
  mounted() {
    const isStandalone = window.matchMedia('(display-mode: standalone)').matches
      || window.navigator.standalone === true

    if (isStandalone) {
      // Already in PWA — change button to show status
      this.el.textContent = 'Instalado ✓'
      this.el.classList.remove('bg-gold-500', 'hover:bg-gold-600', 'cursor-pointer')
      this.el.classList.add('bg-accent-green/20', 'text-accent-green', 'cursor-default')
      this.el.disabled = true
      return
    }

    this.el.addEventListener('click', async () => {
      if (window._deferredPWAPrompt) {
        window._deferredPWAPrompt.prompt()
        const { outcome } = await window._deferredPWAPrompt.userChoice
        if (outcome === 'accepted') {
          this.el.textContent = 'Instalado ✓'
          this.el.disabled = true
        }
        window._deferredPWAPrompt = null
      } else {
        showInstallInstructions()
      }
    })
  }
}

// ---------------------------------------------------------------------------
// Hook: PWANavIcon — persistent install icon in top nav, changes per state
// ---------------------------------------------------------------------------
const PWA_HAPPY_MESSAGES = [
  "Relaxa, voce ja ta no app! Tudo certo por aqui.",
  "Ei, voce ja instalou! Pode dancar tranquilo.",
  "App instalado com sucesso! Agora so falta a sacada.",
  "Voce ja esta usando o app. Nota 10 pra voce!",
  "Ja ta no app, pode comemorar com um xote.",
  "Olha voce, todo moderno no app. Bonito demais!",
  "Instalou e ta usando. Isso sim e compromisso com o forro.",
  "App na mao, forro no coracao. Ta tudo certo!",
]

const PWANavIcon = {
  mounted() {
    const isStandalone = window.matchMedia('(display-mode: standalone)').matches
      || window.navigator.standalone === true

    const icon = this.el.querySelector('svg')
    if (icon && isStandalone) {
      icon.style.color = 'var(--color-accent-green)'
      this.el.title = 'App instalado!'
    }

    this.el.addEventListener('click', () => {
      if (isStandalone) {
        const msg = PWA_HAPPY_MESSAGES[Math.floor(Math.random() * PWA_HAPPY_MESSAGES.length)]
        this.pushEvent("pwa_already_installed", {message: msg})
      } else if (window._deferredPWAPrompt) {
        window._deferredPWAPrompt.prompt()
        window._deferredPWAPrompt.userChoice.then(({ outcome }) => {
          if (outcome === 'accepted') {
            icon.style.color = 'var(--color-accent-green)'
            localStorage.setItem('pwa_banner_dismissed_at', Date.now().toString())
          }
          window._deferredPWAPrompt = null
        })
      } else {
        showInstallInstructions()
      }
    })
  }
}

export { PWAInstall, PWAInstallSettings, PWANavIcon }
