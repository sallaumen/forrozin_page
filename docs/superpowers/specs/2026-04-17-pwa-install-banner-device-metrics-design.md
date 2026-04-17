# PWA Install Banner + Device Metrics — Design Spec

**Data:** 2026-04-17
**Status:** Approved

---

## Resumo

1. **Banner de instalação PWA** — bottom bar compacta (1 linha, 44px) que aparece apenas no browser, esconde no PWA standalone, dismissível por sessão
2. **Badge na landing** — "📱 Disponível como app" no hero
3. **Métricas de device** — tabela `device_sessions` logando tipo de device, browser, e se é PWA por sessão

---

## 1. Banner PWA (bottom bar)

- Fixo no bottom, acima do bottom_nav
- 1 linha: `[ícone 24px] Instale como app [Instalar] [X]`
- `bg-ink-900 text-ink-100`, botão accent-orange
- Lógica JS client-side:
  - `display-mode: standalone` → esconde (já é PWA)
  - Browser → mostra
  - X fecha → `sessionStorage` dismiss → esconde até fechar aba
  - "Instalar" → `deferredPrompt.prompt()` (Android) ou instrução iOS

## 2. Badge landing

Badge inline no hero: `📱 Disponível como app`

## 3. Tabela device_sessions

| Coluna | Tipo |
|--------|------|
| id | binary_id |
| user_id | binary_id FK |
| device_type | string (mobile/desktop/tablet) |
| browser | string |
| is_pwa | boolean |
| user_agent | text |
| inserted_at | timestamp |

1 INSERT por sessão LiveView mount via on_mount hook.

---

## Arquivos

### Criar
- Migration create_device_sessions
- `lib/o_grupo_de_estudos/engagement/device_session.ex`
- `lib/o_grupo_de_estudos_web/hooks/device_tracker.ex`
- `lib/o_grupo_de_estudos_web/components/ui/pwa_install_banner.ex`

### Modificar
- `assets/js/app.js` — PWAInstall hook
- Landing template — badge
- Layout/templates — render banner
