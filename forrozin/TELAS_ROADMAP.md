# Roadmap de Telas — Forrózin

Documento vivo. Atualizado a cada fase concluída.

---

## Mapa de rotas

| Rota               | LiveView / Controller         | Auth?   | Status       |
|--------------------|-------------------------------|---------|--------------|
| `/`                | `LandingLive`                 | Pública | ✅ Fase 1    |
| `/acervo`          | `AcervoLive`                  | Membros | ✅ Fase 1    |
| `/passos/:codigo`  | `PassoLive`                   | Membros | ✅ Fase 2    |
| `/entrar`          | `UserSessionController`       | Pública | ✅ Pronto    |
| `/cadastro`        | `UserRegistrationLive`        | Pública | ✅ Pronto    |
| `/confirmar/:token`| `UserConfirmationController`  | Pública | ✅ Pronto    |
| `/acervo/grafo`    | `GrafoLive` (futuro)          | Membros | ⬜ Fase 5    |
| `/admin`           | `AdminLive` (futuro)          | Admin   | ⬜ Fase 6    |

---

## Fase 1 — Landing + Acervo separados ✅

**Problema resolvido:** HomeLive acumulava landing pública + enciclopédia num único LiveView.

**O que foi feito:**
- `LandingLive` em `/`: página pública com hero, contagem de passos, sobre o autor, CTAs
- `AcervoLive` em `/acervo`: enciclopédia completa (requer autenticação)
- HomeLive removido

**Componentes em `AcervoLive`:**
- `secao_card` — seção colapsável com passos e subseções
- `passo_item` — card do passo com link para `/passos/:codigo`

---

## Fase 2 — Detalhe do passo ✅

**Problema resolvido:** clicar num passo não fazia nada — não havia destino.

**O que foi feito:**
- `PassoLive` em `/passos/:codigo`: página de detalhe do passo
- Exibe: código, nome, categoria, imagem (se existir), nota técnica
- Exibe: conceitos técnicos relacionados
- Exibe: conexões — de onde vem / para onde vai
- `passo_item` no `AcervoLive` agora é um link clicável

**Context additions (`Enciclopedia`):**
- `contar_passos_publicos/0` — para o contador na landing
- `buscar_passo_com_detalhes/2` — passo com categoria, conceitos e conexões

---

## Fase 3 — Thumbnails no acervo ⬜

**O que fazer:**
- Os passos HF-* já têm `caminho_imagem` preenchido e o `passo_item` já renderiza a imagem
- Garantir que as imagens são servidas corretamente (static assets configurados)
- Ajustar tamanho/estilo do thumbnail no card do acervo para ficar mais compacto
- Considerar lazy loading (`loading="lazy"`) para não travar o acervo inteiro

---

## Fase 4 — Animações 3D (Three.js) ⬜

**O que fazer:**
- Schema `StepAnimation`: `step_id`, `keyframes_json` (JSONB), `status`
- Hook LiveView `ThreeCanvas` em `assets/js/hooks/three_canvas.js`
- Componente `ThreeCanvas` no `PassoLive` (substitui/complementa a imagem estática)
- Editor admin para posicionar joints por passo (drag & drop)
- Exportar animação como glTF ou JSON de keyframes

**Dependências:**
- Three.js via npm
- Schema + migration para `step_animations`
- LiveView JS hook com `pushEvent` para sincronizar estado

---

## Fase 5 — Grafo de conexões ⬜

**O que fazer:**
- `GrafoLive` em `/acervo/grafo`
- Visualização interativa do grafo dirigido de passos
- Nós: passos (cor por categoria)
- Arestas: conexões entrada/saída
- Opções: Three.js (3D) ou D3.js (2D)
- Hub central: "Intenção de Sacada"

---

## Fase 6 — Admin + Engagement ⬜

**O que fazer:**
- `AdminLive` em `/admin` (requer `papel: "admin"`)
  - Toggle publicar/esconder passos WIP
  - Dashboard com contagens e métricas
- Feedback por passo (rating 1-5 + texto)
- Page visit tracking (ip_hash, user_id opcional)
- Cache de seções com ETS para desempenho

---

## Componentes reutilizáveis (planejados)

| Componente       | Onde usar                          | Status    |
|------------------|------------------------------------|-----------|
| `categoria_badge`| AcervoLive, PassoLive              | ⬜ extrair |
| `passo_card`     | AcervoLive, busca, admin           | ⬜ extrair |
| `three_canvas`   | PassoLive                          | ⬜ Fase 4  |
| `feedback_form`  | PassoLive                          | ⬜ Fase 6  |
