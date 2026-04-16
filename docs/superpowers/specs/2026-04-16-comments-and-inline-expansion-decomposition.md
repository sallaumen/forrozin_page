# Comments + Inline Expansion — Scope Decomposition

**Data:** 2026-04-16
**Status:** Decomposed, **NOT brainstormed in detail yet** — aguarda ciclos individuais.

Este documento registra a decisão de dividir um pedido amplo do usuário em **3 sub-projetos independentes**, cada um com seu próprio ciclo de brainstorm → spec → plan → implementação.

---

## Pedido original do usuário

1. Comentários aninhados (qualquer comentário pode ter comentários), com likes, inspirado em Instagram
2. Expansão inline no `/collection` — ver comentários e links (incluindo vídeos YouTube) sem sair da página
3. Otimização de performance geral — preparar app pra crescer sem ficar lento

## Por que decompor

Os 3 pedidos tocam camadas arquiteturais distintas:

- **Comentários aninhados** = modelo de dados (self-referential FK), queries recursivas, novas LiveView primitives
- **Expansão inline** = UX, preload em bulk, componentes de expansão
- **Performance** = audit transversal, índices, cache, paginação — depende do sistema estar estabilizado

Tentar fazer num spec só seria impossível de validar, e o risco de um bloquear o outro é alto (ex: schema de comentários mal-modelado vira dor enorme se a expansão inline já estiver construída em cima).

---

## Sub-projeto A: Comentários aninhados + likes

**Escopo:**
- Tabela `comments` com `parent_comment_id` (self-ref)
- Migração de `profile_comments` atual pra esse modelo unificado (OU manter separado — decisão do brainstorm)
- Likes em comentários (já existe `likes` polimórfica)
- Query recursiva limitada (depth-safe)
- UI: thread expansível, contador "X respostas", botão "responder", like visual

**Depende de:** nada (base)

**Bloqueia:** sub-projeto B

---

## Sub-projeto B: Expansão inline no Acervo

**Escopo:**
- No `/collection`, cada `step_item` com comentários/links mostra contadores
- Botão "expandir" mostra inline: lista de comentários + lista de links (com iframe YouTube se aplicável)
- Batch preload dos counters + dos dados expansíveis (sem N+1)
- Cache curto por LiveView mount

**Depende de:** Sub-projeto A (comentários precisam existir como modelo)

**Bloqueia:** nada

---

## Sub-projeto C: Performance geral

**Escopo:**
- Audit de queries em todos os contextos: detectar N+1, slow queries
- Índices faltantes no Postgres (EXPLAIN ANALYZE em queries suspeitas)
- Lazy loading de imagens onde ainda não está
- Paginação em listas de community, profile, admin
- Cache ETS opcional em leituras quentes
- Definir métricas (latência P95, query time)

**Depende de:** ter sub-projetos A + B estabilizados (senão mede performance de código que vai mudar)

**Bloqueia:** nada

---

## Ordem recomendada

1. **A** — comentários aninhados (fundacional)
2. **B** — expansão inline (consome A)
3. **C** — audit de performance (sobre sistema estável)

Cada um vira seu próprio `YYYY-MM-DD-<name>-design.md` via brainstorming skill.

---

## Status atual

**Próximo passo:** brainstorm de Sub-projeto A (após fixes do graph visual que surgiram na validação em produção).
