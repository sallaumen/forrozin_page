# Social Layer — Design Spec

**Goal:** Tornar as features sociais do Forrózin impossíveis de ignorar, espalhando follow, atividade e sugestões por todo o app — em vez de esconder tudo numa aba "Comunidade" que ninguém visita.

**Problema atual:** O botão "Seguir" só existe no perfil do usuário e nos cards da comunidade. Em todas as outras páginas (Acervo, Passo, Mapa, Estudos), o usuário vê usernames mas não pode seguir ali mesmo. Ninguém descobre que o app tem uma dimensão social.

---

## Decisões de Design

| Decisão | Escolha |
|---------|---------|
| Abordagem | Social layer completa: follow inline + bubble + activity pulse + toasts |
| Aba Comunidade | Absorvida — conteúdo migra, bottom nav fica com 6 itens |
| Bubble ao tocar | Popover rápido (3 sugestões + busca, sem modal) |
| Ordem de implementação | Follow inline → Bubble → Remover Comunidade → Activity pulse → Toasts |

---

## Fase 1: Follow Inline em Todas as Páginas

### O que muda

Toda vez que um username aparece no app, um botão "Seguir" aparece ao lado — a menos que o usuário já siga essa pessoa ou seja ele mesmo.

### Páginas afetadas

**Acervo (CollectionLive):**
- Cards de passos com `suggested_by` → adicionar botão "Seguir" ao lado do `@username`
- Já mostra avatar + username, falta só o botão
- O LiveView precisa carregar `following_user_ids` no mount

**Detalhe do Passo (StepLive):**
- Badge "Sugerido por @fulano" → adicionar botão "Seguir" ao lado
- Badge "Editado por @fulano" → adicionar botão "Seguir" ao lado
- Comentários já mostam usernames — NÃO adicionar follow nos comentários (poluiria demais)

**Mapa/Gerador (GraphVisualLive):**
- Cards de sequências no painel lateral → adicionar botão "Seguir" ao lado do `@username`
- Mais complexo porque o grafo é canvas-based — follow fica só nos cards de sequência

**Estudos (StudyLive):**
- Cards de professores/alunos já têm botão "Estudar" — NÃO adicionar follow separado (conflito de ações)

### Componente reutilizável

Criar um componente `inline_follow_button` em `components/ui/`:

```
attrs:
  - target_user_id: string (required)
  - current_user_id: string (required)
  - following_user_ids: MapSet (required)
  - size: :sm | :md (default :sm)
```

Renderiza:
- Nada se `target_user_id == current_user_id`
- "Seguindo ✓" (outline) se já segue
- "Seguir" (filled) se não segue
- `phx-click="toggle_follow"` com `phx-value-user-id`

Touch target mínimo: 36px height (`text-xs py-1 px-3`).

### Evento `toggle_follow` global

O evento `toggle_follow` precisa existir em cada LiveView que usa o componente. Para evitar duplicação, extrair um módulo `FollowHandlers` que pode ser `use`d:

```elixir
defmodule OGrupoDeEstudosWeb.Handlers.FollowHandlers do
  defmacro __using__(_opts) do
    quote do
      def handle_event("toggle_follow", %{"user-id" => target_id}, socket) do
        user = socket.assigns.current_user
        result = OGrupoDeEstudos.Engagement.toggle_follow(user.id, target_id)
        socket = OGrupoDeEstudosWeb.Helpers.RateLimit.maybe_flash_rate_limit(socket, result)
        following = OGrupoDeEstudos.Engagement.following_ids(user.id)
        {:noreply, assign(socket, following_user_ids: following)}
      end
    end
  end
end
```

Cada LiveView que usa follow inline faz `use OGrupoDeEstudosWeb.Handlers.FollowHandlers` e carrega `following_user_ids` no mount.

---

## Fase 2: Floating Bubble + Popover

### Componente global

Criar `components/ui/social_bubble.ex` — renderizado no layout root para todas as páginas autenticadas.

**Bubble:**
- Posição: `fixed bottom-20 right-4` (acima do bottom nav no mobile, bottom-6 no desktop)
- Visual: círculo 48px, gradiente orange, ícone 👥
- Badge de contagem: número de sugestões disponíveis (se > 0)
- Animação sutil de pulse quando há sugestões novas
- Esconde no desktop (`md:hidden`) — desktop usa o sidebar/nav approach

**Popover ao tocar:**
- Aparece acima da bubble, ancorado à direita
- Seta apontando pra bubble
- Conteúdo:
  - Título: "Seguir alguém?"
  - 3 sugestões compactas: avatar + @username + cidade + botão "Seguir"
  - Link "Buscar pessoas..." que foca um input de busca inline
  - Se 0 sugestões: "Você já segue todo mundo! 🎉"
- Fecha ao tocar fora ou ao seguir alguém (atualiza a lista)
- Não bloqueia a tela (sem overlay escuro)

### Dados

O popover precisa de `suggested_users` — usar `Engagement.suggest_users/2` já implementado. Carregar no mount do layout ou via hook JS que faz phx-click.

### Visibilidade

- Mobile: bubble visível em todas as páginas autenticadas
- Desktop: bubble NÃO aparece — desktop terá as sugestões de follow no sidebar/nav futuramente
- Não aparece na landing page, login, signup

---

## Fase 3: Remover Aba Comunidade

### Migração de conteúdo

| Conteúdo atual | Destino |
|---------------|---------|
| Passos sugeridos (tab "Passos") | Acervo — filtro "Sugestões" nos filtros existentes |
| Sequências públicas (tab "Sequências") | Já existem no Mapa/Gerador — remover duplicata |
| Seguidores/Seguindo (tab "Seguidores") | Perfil do usuário — já tem contadores, expandir com lista |
| Busca de pessoas | Bubble popover + busca no Perfil |
| Admin "Pendentes" | Admin dashboard (AdminSuggestionsLive já existe) |

### Bottom nav

Remover "Comunidade" do bottom nav. Resultado: **Acervo · Mapa · Estudos · Gerador · Alertas · Perfil** (6 itens).

### Router

- Manter `/community` como redirect para `/collection` (não quebrar links)
- Remover CommunityLive do router principal eventualmente

### Perfil — expandir seção social

O perfil já mostra contadores de seguindo/seguidores. Adicionar:
- Tap nos contadores abre lista (como Instagram)
- Busca dentro da lista
- Botão follow/unfollow em cada item

---

## Fase 4: Activity Pulse no Top Nav

### Desktop top nav

Adicionar no canto direito do top nav (antes do sino de notificações):
- 3 avatares empilhados (últimos usuários ativos)
- Texto "N online" em orange
- Implementação via Phoenix Presence (já disponível no stack)

### Mobile

Não adicionar ao mobile (espaço limitado no top nav). A sensação de "vivo" vem dos toasts (Fase 5).

### Dados

- `Presence.track` no mount de qualquer LiveView autenticado
- `Presence.list` para contar online
- Mostrar apenas avatares de pessoas que o usuário segue (mais relevante)

---

## Fase 5: Activity Toasts

### Comportamento

Notificações efêmeras que aparecem no topo da tela quando alguém faz algo relevante:
- "@maria curtiu Sacada Simples"
- "@joao criou a sequência Roots Básico"
- "@ana começou a te seguir"

### Regras

- Só mostrar atividade de pessoas que o usuário segue
- Máximo 1 toast por vez, fila de espera
- Auto-dismiss em 4 segundos
- Swipe up para dispensar no mobile
- Tap no toast navega para o conteúdo relevante
- Não mostrar se o usuário está no meio de input (typing)
- Implementação via PubSub — subscribe ao canal do usuário

### Visual

- Barra fina no topo: fundo dark (ink-900), avatar pequeno, texto curto, tempo
- Slide down animation
- Não é intrusivo — apenas informa

---

## Fora de escopo (para o futuro)

- Avatar bubbles de quem curtiu (mostrando rostos em vez de contagem)
- Perfil com foto (upload/crop)
- Direct messages
- @mentions em comentários
- Leaderboard / streaks
- Compartilhar perfil via WhatsApp
