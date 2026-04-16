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

**Nota sobre daisyUI:** será **removido** antes da Fase 1. Dois sistemas (daisyUI + componentes primitivos próprios) competindo gera conflito visual e semântico (classe `btn` do daisyUI vs `<.button>` nosso). Escolhemos um sistema próprio pra ter controle total da identidade visual.

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
| PWA | **Basic** — manifest + service worker mínimo (sem offline). Install prompt usa o automático do navegador (sem botão customizado) | 80% do valor de PWA completa por 20% do esforço; Safari não suporta install prompt programático mesmo |
| Ordem de páginas | **Por uso** — collection → step → graph → community → perfil → auth → admin | Maximiza impacto percebido |

---

## Design de tokens (CSS variables)

**Importante (Tailwind v4.1.12):** `@theme` gera utilities automaticamente só pra namespaces reconhecidos (`--color-*`, `--font-*`, `--text-*`, `--radius-*`, `--shadow-*`, `--ease-*`). Tokens fora desses namespaces (ex: durations customizadas) ficam em `:root` e são consumidos via `var()`.

**Gate de implementação:** na Fase 0b, o primeiro passo é criar **um único token de teste** e validar no build que a utility foi gerada como esperado. Só depois escrever o resto. Isso mitiga risco de divergência entre a doc do Tailwind v4 e o comportamento real da 4.1.12.

### Tokens que geram utilities Tailwind (`@theme`)

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
  --color-gold-500: #d4a054;
  --color-gold-600: #b8893f;

  --color-accent-red:    #c0392b;
  --color-accent-orange: #e67e22;
  --color-accent-green:  #27ae60;
  --color-accent-blue:   #2980b9;

  /* Tipografia */
  --font-serif: Georgia, "Iowan Old Style", serif;
  --font-sans:  "Inter", system-ui, -apple-system, "Segoe UI", sans-serif;

  /* Raios */
  --radius-sm: 4px;
  --radius-md: 6px;
  --radius-lg: 12px;

  /* Sombras */
  --shadow-xs: 0 1px 2px rgba(26,14,5,0.05);
  --shadow-sm: 0 2px 4px rgba(26,14,5,0.06);
  --shadow-md: 0 4px 12px rgba(26,14,5,0.08);
  --shadow-lg: 0 12px 32px rgba(26,14,5,0.12);

  /* Easings (namespace --ease-* suportado) */
  --ease-out-quart: cubic-bezier(0.165, 0.84, 0.44, 1);
  --ease-spring:    cubic-bezier(0.34, 1.56, 0.64, 1);
}
```

### Tokens consumidos via `var()` (`:root`)

Durations e outras constantes não-tokenizáveis pelo Tailwind:

```css
:root {
  --duration-instant: 100ms;
  --duration-fast:    200ms;
  --duration-base:    300ms;
  --duration-slow:    500ms;
}
```

Uso em CSS:
```css
.button:active {
  transition: transform var(--duration-instant) var(--ease-out-quart);
}
```

Ou em inline dinâmico quando necessário (ex: animação customizada):
```heex
<div style={"animation-duration: var(--duration-base);"}>
```

**Tamanhos de texto, line-heights e tracking:** Tailwind v4 já define `text-xs`, `text-sm`, etc. por padrão — **não vamos redefinir**. Se precisar customizar algum tamanho, fazemos via `@utility` específica.

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
| `<.bottom_sheet>` | Wrapper sobre elemento nativo `<dialog>` + CSS (bottom: 0 + translate); mobile: desliza de baixo; desktop (≥md): vira modal centrado. Swipe-to-close implementado em hook JS pequeno (~80 linhas) só pro mobile |
| `<.top_nav>` | Navbar responsiva (desktop: horizontal; mobile detalhe: back button) |
| `<.bottom_nav>` | Tab bar mobile fixa (só em páginas primárias) |
| `<.back_button>` | Voltar mobile com fallback de rota |

**Regra:** function components simples, stateless, com `attr` tipado rigorosamente via `values:` pra estados inválidos serem impossíveis de representar (DDD — alinhado com suas preferências). Sem Storybook — testes unitários de render cobrem a superfície.

**Exemplo de contrato rigoroso (button):**
```elixir
defmodule OGrupoDeEstudosWeb.UI.Button do
  use Phoenix.Component

  attr :variant, :atom, values: [:primary, :ghost, :danger], default: :primary
  attr :size, :atom, values: [:sm, :md, :lg], default: :md
  attr :type, :string, values: ["button", "submit"], default: "button"
  attr :loading, :boolean, default: false
  attr :rest, :global, include: ~w(disabled phx-click phx-value-id data-confirm)
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      data-variant={@variant}
      data-size={@size}
      class={button_classes(@variant, @size)}
      disabled={@loading}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end
end
```

**Por que `data-variant` / `data-size` no DOM:**
- Testes ficam desacoplados de classes Tailwind específicas (podemos refatorar classes sem quebrar testes)
- Debug visual fácil no DevTools
- Contratos semânticos estáveis

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

### Page transitions (mobile) — View Transitions API

LiveView faz DOM patch (não navegação tradicional), então `JS.transition` com slide-in tem risco de flicker — o DOM é substituído enquanto a animação roda.

**Caminho correto:** **View Transitions API** (`document.startViewTransition`), nativa dos browsers, com fallback fade pra onde não suportar.

- **Browsers que suportam:** Chrome 111+, Edge 111+, Safari 18.0+ (setembro 2024), Opera 97+. Cobre ~90%+ do tráfego mobile em 2026.
- **Fallback:** onde não suportado, `JS.transition` faz um cross-fade simples (300ms opacity). Sem slide, mas sem quebrar nada.

Implementação no hook do `<main>`:
```javascript
// Em assets/js/app.js — hook PageTransition
Hooks.PageTransition = {
  mounted() {
    // LiveView executeJS inicia a transition antes do patch
    this.handleEvent("phx:navigate", ({to}) => {
      if (document.startViewTransition) {
        document.startViewTransition(() => {
          // LiveView vai fazer o patch naturalmente
          window.liveSocket.main.pushLinkRedirect(to);
        });
      } else {
        // fallback simples
        window.liveSocket.main.pushLinkRedirect(to);
      }
    });
  }
};
```

CSS das transições (via View Transitions API pseudo-elementos):
```css
@view-transition { navigation: auto; }

::view-transition-old(root),
::view-transition-new(root) {
  animation-duration: var(--duration-base);
  animation-timing-function: var(--ease-out-quart);
}

/* Slide só em mobile */
@media (max-width: 767px) {
  ::view-transition-new(root) {
    animation-name: slide-from-right;
  }
  ::view-transition-old(root) {
    animation-name: slide-to-left;
  }
}

@media (prefers-reduced-motion: reduce) {
  ::view-transition-old(root),
  ::view-transition-new(root) {
    animation: none;
  }
}
```

**Resultado:** slide nativo onde suportado, fade suave onde não, zero fade onde usuário pediu reduced-motion. Sem o inferno de sincronizar animação com DOM patch do LiveView.

- **Desktop:** sem page transitions visíveis (troca de conteúdo normal), mesmo com VT API ativa. Media query acima controla isso.

### Micro-animações

- **Botão `:active`:** `scale(0.97)` em 100ms
- **Card clicável:** `scale(0.98)` + `brightness(0.97)` em 100ms
- **Bottom sheet:** `translate-y: 100% → 0` com `--ease-spring` em 400ms

### Skeleton loaders

Começar **só na Collection** (lista longa, carregamento perceptível). Estilo: retângulos cinza-claros, animação `pulse` de 1.5s (opacity 0.4 ↔ 0.7).

Pra feed da comunidade e grafo: spinner discreto por enquanto. Se depois medirmos que skeleton melhora percepção, adicionamos. YAGNI.

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

`beforeinstallprompt` exige SW com handler `fetch` **presente** (não pode ser totalmente vazio — alguns browsers falham o critério do install prompt sem ele). Mínimo viável:

```javascript
// priv/static/sw.js
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (e) => e.waitUntil(self.clients.claim()));
self.addEventListener("fetch", () => {});  // handler vazio, mas presente
```

Sem cache strategy — passa tudo pra rede. O objetivo aqui é só satisfazer os critérios de PWA instalável.

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

Confiamos no prompt automático do navegador (Chrome mostra banner "Instalar app" quando critérios PWA estão satisfeitos; Safari não suporta `beforeinstallprompt` mesmo).

**Não vamos implementar botão customizado de install** nesta fase. Complexidade alta pra retorno marginal, e Safari (maior parte do tráfego iOS) não é afetado por ele.

Adicionamos instruções claras de "Como instalar" na página **About** — texto simples explicando: Chrome/Edge mostra banner automático; Safari iOS: botão Share → "Adicionar à Tela de Início".

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

### Fix de overflow — corrigir na fonte, não mascarar

**Não vamos usar `overflow-x: hidden` no `<html>` ou `<body>`.** Isso mascara o bug real e causa efeitos colaterais:
- Quebra `position: sticky` (vamos querer no top nav)
- Quebra scroll-to-anchor em alguns browsers
- Esconde regressões futuras

**Abordagem correta:**

```css
/* global: só o essencial */
*, *::before, *::after { box-sizing: border-box; }
img, video, svg { max-width: 100%; height: auto; }
```

Depois, **na Fase 0a**, rodamos o app em mobile real e usamos o DevTools (Inspect Element → "Rendering" panel ou simplesmente `* { outline: 1px solid red }`) pra encontrar o elemento específico que está causando overflow. 90% das vezes é:
- Tabela sem `table-layout: fixed`
- `<pre>` de código ou textarea com largura maior que o viewport
- Grid com `min-content` implícito
- Elemento com `width: 100vw` (que ignora scrollbar e estoura)

Corrigimos esses casos específicos na raiz. Resultado: overflow sumiu sem band-aid.

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

### Fase 0a — Fixes imediatos (deploy o quanto antes)

Valor imediato pro usuário. Deploy independente. Sem tokens ainda, sem componentes.

- Adicionar `*, *::before, *::after { box-sizing: border-box }` e `img, video, svg { max-width: 100%; height: auto }` no CSS global
- Investigar e corrigir na fonte os elementos causando overflow horizontal (tabelas, `<pre>`, elementos com `100vw`)
- Atualizar viewport meta: `viewport-fit=cover`
- Adicionar `@media (prefers-reduced-motion: reduce)` global

**Critério:** site sem scroll horizontal no mobile; nenhum element estoura viewport.

### Fase 0b — Foundation (tokens, PWA, Inter, daisyUI out)

- **Remover daisyUI** do `assets/css/app.css` (imports, plugins, classes daisyUI em arquivos existentes substituídas por Tailwind/inline temporário — detalhado em plano)
- **Validar sintaxe `@theme` Tailwind v4.1.12:** criar um único token de cor, rodar build, confirmar utility gerada; só depois escrever o resto
- Tokens em `@theme` (cores, fontes, raios, sombras, easings)
- Tokens em `:root` (durations)
- Self-host Inter + preload em `priv/static/fonts/Inter-Variable.woff2`
- Safe area insets nos lugares estratégicos (body, bottom nav no futuro)
- PWA: manifest.json, ícones, service worker mínimo (com fetch handler presente)
- Tag `<link rel="manifest">` + meta tags PWA no root layout

**Critério:** build gera classes Tailwind a partir dos tokens (verificável via inspect); Lighthouse PWA > 80; Inter carregando sem FOIT; zero referência a daisyUI restante.

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
| Componentes primitivos | Testes unitários via `render_component/2` verificando **contratos semânticos**: presença de `data-variant`, `data-size`, `role`, `aria-*`, `type`, touch target (via `data-*` ou atributos). **Não testar classes Tailwind** — isso acopla testes à implementação visual. |
| LiveView | `Phoenix.LiveViewTest` verificando estrutura HTML (elementos, `data-*`, eventos `phx-*`) |
| Navegação | Teste de integração: rota primária tem `data-nav="bottom"`, rota detalhe tem `data-nav="detail"` |
| Responsividade | **Manual em device real** (Phoenix.LiveViewTest não tem viewport) |
| Motion | Manual |
| A11y | Lighthouse CI + manual com screen reader |

**Exemplo de teste contratual:**
```elixir
test "button/1 renders with primary variant and touch target" do
  html = render_component(&Button.button/1, %{
    variant: :primary,
    inner_block: fn _, _ -> "Click" end
  })
  assert html =~ ~s(data-variant="primary")
  assert html =~ ~s(data-size="md")
  # touch target verificável via atributo próprio ou estrutura
end
```

**Playwright com screenshots visuais** fica como opcional futuro — custo-benefício não justifica agora.

---

## Métricas de sucesso

Ao final das 9 fases:

1. Lighthouse Performance ≥ 90 em todas as páginas principais (mobile)
2. Lighthouse Accessibility ≥ 95
3. Lighthouse PWA ≥ 90
4. Zero scroll horizontal indesejado em qualquer viewport
5. Touch targets ≥ 44px em 100% dos elementos interativos
6. **Zero inline styles estáticos** em `.heex` templates (dynamic styles legítimos — ex: `style={"transform: translateX(#{@offset}px)"}` — são permitidos e documentados). SVGs inline e atributos `fill`/`stroke` dentro de SVG também são permitidos. Métrica verificável via teste meta em Elixir que lê os arquivos e regex em padrões específicos de strings estáticas (`style="..."` sem interpolação), excluindo SVG e casos marcados explicitamente.
7. App instalável via "Adicionar à tela inicial" com ícone e splash
8. Funciona em iPhone SE (375px) e iPad (1024px)

---

## Fora de escopo

Não entram neste redesign (anotados como próximos possíveis):
- Dark mode (CSS variables já são base suficiente; overrides `[data-theme="dark"]` ficam pra depois)
- PWA offline (service worker com cache)
- Install prompt customizado com botão próprio (Safari não suporta mesmo; automático do Chrome resolve)
- WebP nas imagens (conversão de 54 JPGs)
- Sync em background
- Shared element transitions (tipo imagem do card expandindo)
- i18n (internacionalização)
- Playwright visual regression
- Skeleton loaders em feed e grafo (começamos só na collection)
