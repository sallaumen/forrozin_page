# Mobile-First Redesign + Design System

**Data:** 2026-04-16
**Status:** Approved — pronto pra writing-plans
**Escopo:** Todo o app — 13 páginas LiveView, ~725 inline styles → Tailwind + design system

---

## Contexto e motivação

O site está online em produção (https://ogrupodeestudos.com.br), mas **não é utilizável no mobile**:
- Aparece barra cinza à esquerda (overflow horizontal indesejado)
- Scroll horizontal ativo permite "puxar" a página lateralmente
- Botões e labels em fontes muito pequenas (11-13px serif) pra touch
- Nenhuma adaptação de layout pra telas pequenas

**Causa raiz:** 725 atributos `style="..."` inline espalhados em 13 páginas. Inline styles **não aceitam media queries**, então responsividade é fisicamente impossível no estado atual.

**Estado do tooling:** Tailwind v4.1.12 e daisyUI já estão configurados em `assets/css/app.css` mas praticamente não são usados nas páginas de conteúdo — só em layouts e auth. Viewport meta tag existe.

**Objetivo:** transformar o app em experiência mobile com qualidade comparável a big tech (Linear, Stripe, Notion), mantendo a identidade visual sepia/earth-tones atual.

---

## Decisões arquiteturais

| Decisão | Escolha | Rationale |
|---------|---------|-----------|
| Padrão de navegação | **Hybrid** — bottom nav em páginas primárias, top nav com back em detalhe | Imita apps nativos iOS; 75% dos usuários mobile seguram celular com uma mão |
| Sistema visual | **Preservar + refinar** paleta atual, codificar em tokens | Mantém personalidade; viabiliza refactor em um lugar só |
| Dark mode | **Não implementar agora** | O uso de CSS variables já deixa dark mode adicionável no futuro sem refactor; tokens não precisam de estrutura adicional |
| Tipografia | **Dual: Georgia (conteúdo) + Inter (UI)** | Serif ruim em UI de 11-14px; Inter é padrão indústria pra UI |
| Motion | **Moderate** — page transitions, bottom sheets, micro-animações de tap, skeleton loaders | Feeling nativo sem custo de shared element transitions |
| PWA | **Basic** — manifest + service worker mínimo + install prompt | 80% do valor de PWA completa por 20% do esforço |
| Ordem de páginas | **Por uso** — collection → step → graph → community → perfil → auth → admin | Maximiza impacto percebido |

---

## Design de tokens (CSS variables)

Em `assets/css/app.css`:

```css
@theme {
  /* Cores — preserva paleta sepia, codifica em escala 50-900 */
  --color-ink-50:  #fdfbf8;
  --color-ink-100: #f7f3ec;   /* paper background */
  --color-ink-200: #ede8df;
  --color-ink-300: #d4cabb;
  --color-ink-400: #bba88a;
  --color-ink-500: #9a7a5a;
  --color-ink-600: #7a5c3a;
  --color-ink-700: #5c3a1a;
  --color-ink-800: #3a2410;
  --color-ink-900: #1a0e05;   /* texto principal */

  --color-gold-400: #e6b97e;
  --color-gold-500: #d4a054;   /* accent dourado */
  --color-gold-600: #b8893f;

  --color-accent-red:    #c0392b;
  --color-accent-orange: #e67e22;
  --color-accent-green:  #27ae60;
  --color-accent-blue:   #2980b9;

  /* Tipografia */
  --font-serif: Georgia, "Iowan Old Style", serif;
  --font-sans:  "Inter", system-ui, -apple-system, "Segoe UI", sans-serif;

  /* Escala de tamanhos */
  --text-xs: 0.75rem;    /* 12px */
  --text-sm: 0.875rem;   /* 14px */
  --text-base: 1rem;     /* 16px */
  --text-lg: 1.125rem;   /* 18px */
  --text-xl: 1.25rem;    /* 20px */
  --text-2xl: 1.5rem;    /* 24px */
  --text-3xl: 1.875rem;  /* 30px */
  --text-4xl: 2.25rem;   /* 36px */

  --leading-tight: 1.25;
  --leading-normal: 1.5;
  --leading-relaxed: 1.7;

  --tracking-widest: 0.1em;

  /* Raios */
  --radius-sm: 4px;
  --radius-md: 6px;
  --radius-lg: 12px;
  --radius-full: 9999px;

  /* Sombras */
  --shadow-xs: 0 1px 2px rgba(26,14,5,0.05);
  --shadow-sm: 0 2px 4px rgba(26,14,5,0.06);
  --shadow-md: 0 4px 12px rgba(26,14,5,0.08);
  --shadow-lg: 0 12px 32px rgba(26,14,5,0.12);

  /* Motion */
  --ease-out-quart: cubic-bezier(0.165, 0.84, 0.44, 1);
  --ease-spring:    cubic-bezier(0.34, 1.56, 0.64, 1);
  --ease-in-out:    cubic-bezier(0.4, 0, 0.2, 1);

  --duration-instant: 100ms;
  --duration-fast: 200ms;
  --duration-base: 300ms;
  --duration-slow: 500ms;
}
```

**Breakpoints** (default Tailwind): mobile <640px, sm ≥640px, md ≥768px, lg ≥1024px, xl ≥1280px.

---

## Componentes primitivos

Em `lib/o_grupo_de_estudos_web/components/ui/`:

| Componente | Responsabilidade |
|------------|------------------|
| `<.container>` | Wrapper com padding + max-width responsivos (px-4 sm:px-6 lg:px-8, max-w-4xl) |
| `<.page_header>` | Título, breadcrumb, action slot; responsivo |
| `<.card>` | Padrão visual de card (bg, border, radius, sombra) |
| `<.button>` | Variantes (primary, ghost, danger) × tamanhos (sm, md, lg); loading state |
| `<.icon_button>` | Botão só com ícone, garante 44×44px clicáveis |
| `<.input>`, `<.textarea>`, `<.select>` | Form controls com label, error, hint |
| `<.badge>` | Tags (categoria, status) |
| `<.skeleton>` | Placeholder com shimmer sutil |
| `<.bottom_sheet>` | Modal mobile que desliza de baixo com swipe-to-close; vira modal centrado em ≥md |
| `<.top_nav>` | Navbar responsiva (desktop: horizontal; mobile detalhe: back button) |
| `<.bottom_nav>` | Tab bar mobile fixa (só em páginas primárias) |
| `<.back_button>` | Voltar mobile com fallback de rota |

**Regra:** function components simples, stateless, tipadas com `attr`. Sem Storybook — testes unitários de render cobrem a superfície.

---

## Sistema de navegação (Hybrid)

### Classificação de páginas

**Primárias** (bottom nav visível em mobile):
- `/collection` — Acervo
- `/graph/visual` — Mapa
- `/community` — Comunidade
- `/users/:username` — Perfil (só se for o próprio)

**Detalhe** (bottom nav escondida, top nav com back):
- `/steps/:code`
- `/users/:username` (outro usuário)
- `/settings`
- `/sequences/:id`
- Admin pages (`/admin/links`, `/admin/backups`)

### Implementação

```elixir
# lib/o_grupo_de_estudos_web/navigation.ex
defmodule OGrupoDeEstudosWeb.Navigation do
  def on_mount(:primary, _params, _session, socket) do
    {:cont, Phoenix.Component.assign(socket, :nav_mode, :primary)}
  end

  def on_mount(:detail, _params, _session, socket) do
    {:cont, Phoenix.Component.assign(socket, :nav_mode, :detail)}
  end
end
```

LiveViews adicionam `on_mount {OGrupoDeEstudosWeb.Navigation, :primary}` ou `:detail`. Root layout renderiza `<.bottom_nav>` se `@nav_mode == :primary`.

### Touch targets

- Tab da bottom nav: 56px altura (+ safe-area-inset-bottom)
- Ícone 24×24 + label 11px abaixo
- Item ativo: `text-ink-900`; inativo: `text-ink-500`
- Ícones: heroicons v2 (via plugin Tailwind já instalado)

### Admin no mobile

Links admin (Conexões, Links, Backups) **não aparecem na bottom nav**. Vão dentro de **Perfil → submenu "Administração"**. Mantém navegação principal limpa.

---

## Tipografia

### Self-host Inter

Arquivo: `priv/static/fonts/Inter-Variable.woff2` (~110KB, variable font).

```css
@font-face {
  font-family: "Inter";
  font-weight: 100 900;
  font-display: swap;
  src: url("/fonts/Inter-Variable.woff2") format("woff2-variations");
}
```

Preload no root layout:
```heex
<link rel="preload" href="/fonts/Inter-Variable.woff2" as="font" type="font/woff2" crossorigin />
```

### Regras de uso

| Elemento | Fonte | Mobile | Desktop |
|----------|-------|--------|---------|
| `<h1>` (page title) | Serif | `text-3xl` | `text-4xl` |
| `<h2>` (section) | Serif | `text-xl` | `text-2xl` |
| `<h3>` (sub) | Sans bold | `text-base` | `text-lg` |
| Body (descrições de passos) | Serif | `text-base leading-relaxed` | idem |
| UI labels | Sans uppercase | `text-xs tracking-widest` | idem |
| Botões | Sans medium | `text-sm` | `text-sm` |
| Links navbar | Sans | `text-base` | `text-base` |
| Código (BF, SC) | Monospace | `text-sm` | `text-sm` |
| Metadados (datas) | Sans | `text-xs` | `text-xs` |

**Regra inviolável:** nenhum texto menor que 14px (text-xs/12px só pra metadados não-críticos).

---

## Motion

### Page transitions (mobile)

- **Primária → Detalhe:** página nova slide-in da direita (translate-x: 100% → 0); bottom nav desliza pra baixo; 300ms `--ease-out-quart`
- **Detalhe → Primária:** reverso
- **Desktop:** sem page transitions (só troca de conteúdo normal)

Implementação: `Phoenix.LiveView.JS.transition` + CSS classes — sem framework externo.

### Micro-animações

- **Botão `:active`:** `scale(0.97)` em 100ms
- **Card clicável:** `scale(0.98)` + `brightness(0.97)` em 100ms
- **Bottom sheet:** `translate-y: 100% → 0` com `--ease-spring` em 400ms

### Skeleton loaders

Substituem spinners em lista da collection, feed, grafo. Estilo: retângulos cinza-claros, animação `pulse` de 1.5s (opacity 0.4 ↔ 0.7).

### Accessibility

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

### Proibido

- Parallax
- Scroll-triggered "reveals" genéricos
- Staggered list animations
- Page transitions no desktop

---

## PWA

### Manifest (`priv/static/manifest.json`)

```json
{
  "name": "O Grupo de Estudos",
  "short_name": "Grupo de Estudos",
  "description": "Acervo de forró roots",
  "start_url": "/collection",
  "display": "standalone",
  "orientation": "portrait",
  "background_color": "#f7f3ec",
  "theme_color": "#1a0e05",
  "icons": [
    { "src": "/icons/icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/icons/icon-512.png", "sizes": "512x512", "type": "image/png" },
    { "src": "/icons/icon-512-maskable.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ]
}
```

### Service Worker mínimo (`priv/static/sw.js`)

Vazio — só a existência + scope ativa o install prompt do navegador. Sem cache strategy.

### Root layout

```heex
<link rel="manifest" href="/manifest.json" />
<meta name="theme-color" content="#1a0e05" />
<meta name="apple-mobile-web-app-capable" content="yes" />
<meta name="apple-mobile-web-app-status-bar-style" content="default" />
<link rel="apple-touch-icon" href="/icons/icon-192.png" />
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
```

### Install prompt

Hook `InstallPrompt` em `assets/js/app.js`:
- Escuta `beforeinstallprompt`, armazena deferido
- Mostra botão "Instalar app" no menu do Perfil
- Ao clicar, chama `prompt()`

Se já instalado ou não suportado, botão some.

---

## Performance

### Critical path

1. **Fontes:** Inter preload + `font-display: swap`; system fallback renderiza primeiro
2. **CSS:** Tailwind v4 purga automaticamente → alvo <40KB gzipped
3. **JS critical:** bundle atual ~40KB com Three.js/Cytoscape/LiveView
4. **Lazy-load Cytoscape:** só carrega em `/graph/visual`

```javascript
// assets/js/app.js
if (document.getElementById("cy")) {
  const { default: cytoscape } = await import("./vendor/cytoscape.min.js");
  // init...
}
```

Ganho esperado: ~25KB cortados do bundle inicial.

5. **Imagens:** `loading="lazy"` em imagens fora da viewport inicial. WebP fica como próximo passo (fora deste escopo).

### Safe areas (iPhone notch/home bar)

```css
.bottom-nav {
  padding-bottom: env(safe-area-inset-bottom);
  height: calc(56px + env(safe-area-inset-bottom));
}
```

### Fix imediato de overflow

```css
html, body {
  overflow-x: hidden;
  width: 100%;
  max-width: 100vw;
}
* { max-width: 100%; box-sizing: border-box; }
img { max-width: 100%; height: auto; }
```

Resolve 90% dos bugs de scroll horizontal.

---

## Touch targets

Regra: todo elemento interativo em mobile ≥ **44×44px** (Apple HIG).

- Botões `sm`: altura visual 36px + hitbox invisível de 44px
- Icon buttons: wrapper 44×44, ícone 20×20 centralizado
- Links em lista: `py-3` mínimo

Estado atual tem vários botões de `padding: 4px` e fonte 11px — impossível de acertar com polegar. Refactor resolve.

---

## Fases de implementação

Cada fase = 1 PR independente, deploy independente, sem quebrar o app no meio. **Após cada fase, usuário testa manualmente e aprova antes de push.**

### Fluxo por fase

```
1. Agent implementa a fase
2. Agent roda mix test — todos verdes
3. Agent comita localmente (NÃO push)
4. Agent avisa usuário: "Fase X pronta. Teste localmente."
5. Usuário testa (mix phx.server + browser)
6. Usuário aprova ou pede ajustes
7. Após aprovação: agent faz push, espera CD, valida em produção
8. Próxima fase
```

### Fase 0 — Foundation

- CSS overflow fixes (html/body/img)
- Tokens em `app.css`
- Self-host Inter + preload
- Viewport com `viewport-fit=cover`
- Safe area CSS
- `prefers-reduced-motion` global
- PWA manifest + SW + install prompt hook

**Critério:** site sem scroll horizontal no mobile; Lighthouse PWA > 80.

### Fase 1 — Componentes primitivos

Todos os componentes listados em "Componentes primitivos" + testes unitários.

**Critério:** componentes existem com testes; nenhuma página consome ainda.

### Fase 2 — Navegação híbrida

- `<.top_nav>` responsiva
- `<.bottom_nav>`
- `<.back_button>`
- `Navigation.on_mount/4`
- Page transitions mobile

**Critério:** mobile tem bottom nav em primárias e back em detalhes; transição suave.

### Fase 3 — Collection mobile

- `collection_live.html.heex` migrado
- Grid: 1 col <640, 2 col 640-1024, 3 col ≥1024
- Search/filtros em bottom sheet no mobile

**Critério:** collection perfeita no mobile; Lighthouse Performance > 90.

### Fase 4 — Step detail mobile

- `step_live.html.heex` migrado
- Top nav com back
- Forms em bottom sheet no mobile
- Conexões viram lista vertical no mobile

### Fase 5 — Graph visual mobile

- Cytoscape lazy-loaded
- Touch gestures (pinch-zoom, pan)
- Drawer vira bottom sheet
- Controles em FAB

**Crítico:** testar em device real.

### Fase 6 — Community + Profile + Settings

- Feed com pull-to-refresh
- Profile compacto com tabs

### Fase 7 — Auth flows mobile

- Registro/login
- Autocomplete de cidades em bottom sheet full-screen
- `inputmode` + `autocomplete` corretos

### Fase 8 — Admin mobile

- Admin pages funcionais no mobile (não prioriza; tabelas viram cards)

### Fase 9 — Polish + accessibility audit

- Lighthouse em todas páginas
- Touch target audit
- Focus rings consistentes
- Screen reader smoke test (VoiceOver/TalkBack)
- Real device testing (iPhone SE, iPhone 15 Pro, Android entrada)

---

## Testing

| Tipo | Método |
|------|--------|
| Componentes primitivos | Testes unitários renderizando com attrs |
| LiveView | `Phoenix.LiveViewTest` verificando classes Tailwind |
| Navegação | Teste de integração por rota |
| Responsividade | **Manual em device real** (Phoenix.LiveViewTest não tem viewport) |
| Motion | Manual |
| A11y | Lighthouse CI + manual com screen reader |

**Playwright com screenshots visuais** fica como opcional futuro — custo-benefício não justifica agora.

---

## Métricas de sucesso

Ao final das 9 fases:

1. Lighthouse Performance ≥ 90 em todas as páginas principais (mobile)
2. Lighthouse Accessibility ≥ 95
3. Lighthouse PWA ≥ 90
4. Zero scroll horizontal indesejado em qualquer viewport
5. Touch targets ≥ 44px em 100% dos elementos interativos
6. **Zero inline styles** em `lib/o_grupo_de_estudos_web/live/**` — verificável via grep
7. App instalável via "Adicionar à tela inicial" com ícone e splash
8. Funciona em iPhone SE (375px) e iPad (1024px)

---

## Fora de escopo

Não entram neste redesign (anotados como próximos possíveis):
- Dark mode (CSS variables já são base suficiente; overrides `[data-theme="dark"]` ficam pra depois)
- PWA offline (service worker com cache)
- WebP nas imagens (conversão de 54 JPGs)
- Sync em background
- Shared element transitions (tipo imagem do card expandindo)
- i18n (internacionalização)
- Playwright visual regression
