# Graph Visual — Sequence UX Improvements

**Data:** 2026-04-16
**Status:** Approved — pronto pra writing-plans
**Escopo:** Melhorias UX focadas na `/graph/visual` — sequence highlight persistence, auto-open sequence panel, multi-position numbering, dropdown bugs.

---

## Contexto

O `/graph/visual` já foi migrado pro Tailwind (Phase 3d) e Cytoscape foi lazy-loaded (Phase 4). Mas durante uso real, cinco pontos de UX emergiram como atrito:

1. **Fade volta ao normal quando drawer abre/fecha** — ao selecionar uma sequência, os nós fora dela ficam com `opacity 0.12` (fade). Ao clicar num nó (abre drawer) e depois fechar, o fade desaparece — só laranja dos nós da sequência persiste. Visualmente quebra a "imersão" no modo sequência.
2. **Painel de sequências fica escondido por padrão** — usuário não descobre o recurso. É uma das features mais poderosas mas apagada.
3. **"Sair da sequência" precisa ser o único exit explícito** — pra sinalizar contrato claro de entrada/saída do modo.
4. **Nó que aparece múltiplas vezes numa sequência mostra só último número** — ex: `BF → SC → BF` mostra BF como `③` (perde a posição `①`).
5. **Dropdowns (autocomplete) visualmente quebrados** — bg transparente e não fecham ao clicar fora.

---

## Decisões de design

| Aspecto | Decisão | Rationale |
|---------|---------|-----------|
| Persistência do fade | Handlers de massa respeitam `_seqHighlightActive` | Menos invasivo que re-aplicar highlights após cada evento |
| Painel aberto default | Desktop: painel aberto. Mobile: botão "Sequências" visível | Incentiva descoberta sem ocupar tela no mobile |
| Exit de sequência | Botão "Sair da sequência" no canto superior direito é o único way | Contrato claro; abrir drawer NÃO sai do modo |
| Números múltiplos | Agrupar posições por código, exibir `① ③` | Preserva informação de rota |
| Dropdown bg | Trocar `bg-white` por `bg-ink-50` | `bg-ink-50` é token nosso, sem dependências de `--color-white` |
| Dropdown close | `phx-click-away` do LiveView | Nativo, sem JS novo |

---

## Arquitetura

**Sem mudanças em schema, contexto ou testes de domínio.** É refinamento de UX em `graph_visual_live.*` e `assets/js/app.js`.

### Pontos de intervenção

1. **`assets/js/app.js`**:
   - Function `_applySequenceHighlight(stepCodes)` — alterar loop pra agrupar posições por code
   - Mouse handlers (`mouseover`, `mouseout`) — já têm guard `_seqHighlightActive`, verificar se há outros handlers que resetam opacity sem o guard
   - Drawer open/close — garantir que não mexe em opacity quando sequence ativo
   - Exit button (`_showSeqExitButton`) — verificar que chama `_clearSequenceHighlight()` completamente

2. **`lib/o_grupo_de_estudos_web/live/graph_visual_live.ex`**:
   - Assign `@seq_panel` — default `true` (painel aberto)
   - Adicionar assign `@seq_mobile_visible` — default `false` (mobile começa com painel fechado; botão "Sequências" no topo abre)

3. **`lib/o_grupo_de_estudos_web/live/graph_visual_live.html.heex`**:
   - Painel lateral desktop: mostra por default
   - Mobile: botão "Sequências" flutuante; painel é overlay full-screen que abre no tap
   - Dropdowns (autocomplete): `bg-ink-50` + `phx-click-away="hide_suggestions"` (novo handler no LV)

---

## Detalhamento por bloco

### Bloco 1 — Fade persistente durante sequence mode

**Problema raiz**: quando drawer abre, `openDrawer` (em `app.js`) possivelmente reseta opacity de nós via `cy.elements().style({ opacity: 1 })`. Ao fechar, não restaura a fade.

**Solução**:
- Auditar TODAS chamadas `cy.elements().style({ opacity: ... })` e `cy.elements().style({...})` em `app.js`.
- Cada uma que zera/restaura opacidade DEVE primeiro checar `if (this._seqHighlightActive) return` (ou o equivalente com hook).
- Centralizar: criar helper `_withSeqGuard(fn)` que executa a função só se `_seqHighlightActive === false`.

**Alternativa considerada e rejeitada**: re-aplicar `_applySequenceHighlight` após cada evento que reseta styles. Rejeitada porque (a) é reativa, (b) custa extra frames de render, (c) aumenta superfície de bugs.

### Bloco 2 — Painel de sequências aberto por default

**Desktop (≥md)**:
- Assign `@seq_panel = true` no mount. Usuário pode fechar com ✕ no canto superior direito do painel.
- Ainda mantém um toggle visível quando painel fechado pra re-abrir (já existe? verificar).

**Mobile (<md)**:
- Assign `@seq_mobile_visible = false` no mount.
- Botão flutuante fixo "Sequências" no canto inferior direito (ou topo) visível sempre.
- Tap abre painel como **overlay full-screen** (cobre grafo).
- Dentro do overlay, botão X fecha e retorna pro grafo.
- Estado persiste durante sessão (não reseta em navegação interna).

**Estrutura CSS**:
```heex
<%!-- Mobile "Sequências" floating trigger --%>
<button
  :if={!@seq_mobile_visible}
  class="md:hidden fixed bottom-20 right-4 z-30 bg-ink-900 text-ink-100 px-4 py-2 rounded-full shadow-lg"
  phx-click="show_seq_mobile"
>
  Sequências
</button>

<%!-- Panel: on desktop, side-anchored. On mobile, full-screen overlay --%>
<div class={[
  "md:relative md:w-[280px] md:h-full",  <!-- desktop: inline sidebar -->
  "fixed inset-0 md:static z-40",  <!-- mobile: overlay -->
  !@seq_panel && "md:hidden",  <!-- desktop closed state -->
  !@seq_mobile_visible && "hidden md:block",  <!-- mobile closed state -->
]}>
  <!-- existing panel content -->
</div>
```

### Bloco 3 — "Sair da sequência" como exit ÚNICO

Auditar `_clearSequenceHighlight()`:
- Remove orange outlines ✓ (já faz)
- Restora opacity de todos nós pra 1.0 ✓ (já faz)
- Remove labels circulados ①②③ restaurando `_origLabel` ✓ (já faz)
- Recentraliza câmera ✓ (já faz via `cy.fit()`)

Verificar que **nenhum outro caminho chama `_clearSequenceHighlight()`**. Os únicos triggers devem ser:
1. Botão "Sair da sequência" (top-right)
2. Botão "Limpar destaque" no painel de sequência
3. Escolher outra sequência (chama clear automaticamente antes de aplicar nova)

**Expansão**: adicionar Escape keyboard shortcut pra "Sair da sequência" — paralelo ao Esc que fecha drawer.

### Bloco 4 — Números múltiplos em nós repetidos

Lógica atual em `_applySequenceHighlight(stepCodes)`:

```javascript
stepCodes.forEach((code, idx) => {
  const node = cy.getElementById(code)
  const originalLabel = node.data("label")
  node.data("_origLabel", originalLabel)
  node.data("label", `${circledNumber(idx+1)}\n${originalLabel}`)
  // ... styles
})
```

**Problema**: se `code` aparece em `idx=0` e `idx=2`, o segundo `node.data("label", ...)` sobrescreve o primeiro.

**Nova lógica**:

```javascript
// 1. Agrupar posições por code
const positionsByCode = {}
stepCodes.forEach((code, idx) => {
  positionsByCode[code] = positionsByCode[code] || []
  positionsByCode[code].push(idx + 1)
})

// 2. Aplicar labels com todas as posições
Object.entries(positionsByCode).forEach(([code, positions]) => {
  const node = cy.getElementById(code)
  if (node.length === 0) return

  const originalLabel = node.data("_origLabel") || node.data("label")
  node.data("_origLabel", originalLabel)

  const prefix = positions.map(circledNumber).join(" ")
  node.data("label", `${prefix}\n${originalLabel}`)
  // ... styles
})
```

**Result**: nó BF em sequência `BF → SC → BF` mostra label `① ③\nBase Frontal`.

**Edge case**: sequência com mais de 20 posições — `circledNumber` pode não ter glyph. Retornar `(N)` em string normal se > 20.

### Bloco 5 — Dropdowns bg + click-away

**Dois dropdowns afetados** (ambos em `graph_visual_live.html.heex`):
- Linha ~112: start step autocomplete
- Linha ~194: required step autocomplete

**Fix 1 — Background**:
```heex
<div
  class="absolute top-full left-0 right-0 z-50 bg-ink-50 border border-ink-900/15 rounded-b shadow-md"
  ...
>
```
(Trocar `bg-white` por `bg-ink-50`.)

**Fix 2 — Click-away**:
```heex
<div
  phx-click-away="hide_seq_suggestions"
  class="..."
>
```

E adicionar no LV:
```elixir
def handle_event("hide_seq_suggestions", _, socket) do
  {:noreply, assign(socket, seq_start_suggestions: [], seq_required_suggestions: [])}
end
```

---

## Fora de escopo

- **Playback de sequência** (step-by-step com controls prev/next) — feature maior, não cabe aqui
- **Compartilhamento público de sequência** (link direto) — não pedido
- **Comentários em sequência da comunidade** — futuro
- **Reordenar passos via drag numa sequência saved** — fora desse spec

---

## Métricas de sucesso

1. Selecionar sequência → abrir drawer → fechar drawer: **fade permanece** em nós não-sequência
2. Abrir `/graph/visual` no desktop: painel de sequências **já aberto**
3. Abrir `/graph/visual` no mobile: **botão "Sequências"** visível, tap abre overlay
4. Clicar "Sair da sequência": **TUDO volta ao normal** (sem resíduo de laranja, opacity, labels)
5. Sequência `BF → SC → BF`: nó BF mostra `① ③` labels
6. Digitar em autocomplete: dropdown tem **bg sólido** (ink-50)
7. Clicar fora do dropdown: **dropdown fecha**
