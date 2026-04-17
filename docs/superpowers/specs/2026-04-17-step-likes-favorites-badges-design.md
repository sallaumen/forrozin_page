# Step Likes + Favoritos Públicos + Badges — Design Spec

**Data:** 2026-04-17
**Status:** Approved — pronto para plano de implementação

---

## Resumo

Três features coesas que transformam likes em moeda social visível:

1. **Like button em passos** em todas as páginas (collection, step detail, community, grafo)
2. **Favoritos públicos** como aba no perfil + grid de stats clicável
3. **Badges de gamificação** calculados on-demand com micro-badge ao lado do username

---

## 1. Like Button em Passos

### Onde aparece

| Página | Posição | Comportamento |
|--------|---------|---------------|
| `/collection` (step_item) | Coluna direita, junto a 👤 e 🎬 | `hero-heart` 16px + `like_count` em vermelho se liked, ink-400 se não |
| `/collection` (expansão inline) | Header do painel expandido | Coração + count, padrão dos comments |
| `/steps/:code` | Abaixo do título, antes da nota | `hero-heart` 20px + "X curtidas" texto |
| `/community` (step cards) | Lateral do card | Coração + count |
| `/users/:username` (perfil) | Já existe — manter |
| `/graph/visual` | Badge no nó Cytoscape | **Só pessoal**: coração vermelho se user curtiu, sem contagem |

### Grafo — comportamento especial

- No mount: `liked_step_ids = Engagement.liked_step_ids(user.id)` retorna `MapSet`
- Nós curtidos: borda vermelha fina (2px `#c0392b`) via Cytoscape style
- Ao dar like em qualquer passo (via drawer ou outra página), `push_event("update_liked_steps", %{ids: [...]})` atualiza o grafo sem reload
- Sem like_count no grafo — indicador pessoal, não social

### Backend

Nova função:

```elixir
def liked_step_ids(user_id) do
  from(l in Like,
    where: l.user_id == ^user_id and l.likeable_type == "step",
    select: l.likeable_id
  )
  |> Repo.all()
  |> MapSet.new()
end
```

Cada página carrega `step_likes = Engagement.likes_map(user.id, "step", step_ids)` — já existe na maioria.

### Evento `toggle_step_like`

Todas as páginas usam o mesmo handler pattern:

```elixir
def handle_event("toggle_step_like", %{"id" => step_id}, socket) do
  user = socket.assigns.current_user
  case Engagement.toggle_like(user.id, "step", step_id) do
    {:ok, _} -> {:noreply, reload_step_likes(socket)}
    {:error, _} -> {:noreply, socket}
  end
end
```

O `reload_step_likes` é específico de cada LiveView (recarrega os assigns relevantes).

---

## 2. Favoritos Públicos no Perfil

### Nova aba "Favoritos"

O `UserProfileLive` ganha uma terceira aba visível a todos:

```
┌──────────┐ ┌──────────┐ ┌──────────┐
│  Passos  │ │Sequências│ │Favoritos ★│
└──────────┘ └──────────┘ └──────────┘
```

**Conteúdo:**
- Passos que o user curtiu, ordenados por data do like (mais recente primeiro)
- Cada item: code pill + nome + categoria badge + like button
- Próprio user pode unlike direto (remove dos favoritos)
- Lazy-loaded ao clicar na aba

**Query:**

```elixir
def list_liked_steps(user_id) do
  from(l in Like,
    where: l.user_id == ^user_id and l.likeable_type == "step",
    join: s in Step, on: s.id == l.likeable_id,
    where: is_nil(s.deleted_at) and s.status == "published",
    order_by: [desc: l.inserted_at],
    select: s,
    preload: [:category]
  )
  |> Repo.all()
end
```

### Grid de Stats no topo do perfil

Abaixo do nome/bio, acima das abas:

```
┌──────────┐ ┌──────────┐ ┌──────────┐
│    23    │ │    12    │ │     5    │
│ curtidas │ │favoritos │ │sequências│
└──────────┘ └──────────┘ └──────────┘
```

| Stat | Valor | Clicável |
|------|-------|----------|
| Curtidas | Total de likes recebidos (comments do user que foram curtidos) | Não |
| Favoritos | Quantidade de steps curtidos pelo user | Sim → aba Favoritos |
| Sequências | Quantidade de sequências públicas do user | Sim → aba Sequências |

**Cálculo "curtidas recebidas":**

```elixir
def total_likes_received(user_id) do
  # Likes em step_comments do user
  sc = from(l in Like,
    join: c in StepComment, on: c.id == l.likeable_id and l.likeable_type == "step_comment",
    where: c.user_id == ^user_id,
    select: count(l.id)
  ) |> Repo.one()

  # Likes em sequence_comments do user
  qc = from(l in Like,
    join: c in SequenceComment, on: c.id == l.likeable_id and l.likeable_type == "sequence_comment",
    where: c.user_id == ^user_id,
    select: count(l.id)
  ) |> Repo.one()

  # Likes em profile_comments do user
  pc = from(l in Like,
    join: c in ProfileComment, on: c.id == l.likeable_id and l.likeable_type == "profile_comment",
    where: c.author_id == ^user_id,
    select: count(l.id)
  ) |> Repo.one()

  (sc || 0) + (qc || 0) + (pc || 0)
end
```

**Estilo:** número em `text-2xl font-bold text-ink-800`, label em `text-xs text-ink-500`. Clicáveis com `cursor-pointer hover:bg-ink-100 rounded-lg p-3`.

---

## 3. Badges de Gamificação

### Tabela de badges

| Badge | Ícone | Critério | Cor |
|-------|-------|----------|-----|
| Explorador | 🧭 | Curtiu 5+ passos | accent-orange |
| Curador | ⭐ | Curtiu 15+ passos | gold-500 |
| Comentarista | 💬 | Fez 5+ comentários (qualquer tipo) | accent-blue |
| Voz Ativa | 🎤 | Fez 15+ comentários | accent-orange |
| Popular | ❤️ | Recebeu 10+ likes em comentários | accent-red |
| Estrela | 🌟 | Recebeu 25+ likes em comentários | gold-500 |

### Cálculo — sem tabela nova

Módulo puro `Engagement.Badges`:

```elixir
defmodule OGrupoDeEstudos.Engagement.Badges do
  @badges [
    %{key: :estrela, icon: "🌟", name: "Estrela", threshold: 25, metric: :likes_received},
    %{key: :popular, icon: "❤️", name: "Popular", threshold: 10, metric: :likes_received},
    %{key: :voz_ativa, icon: "🎤", name: "Voz Ativa", threshold: 15, metric: :comments_count},
    %{key: :comentarista, icon: "💬", name: "Comentarista", threshold: 5, metric: :comments_count},
    %{key: :curador, icon: "⭐", name: "Curador", threshold: 15, metric: :likes_given},
    %{key: :explorador, icon: "🧭", name: "Explorador", threshold: 5, metric: :likes_given}
  ]

  def compute(user_id) do
    metrics = fetch_metrics(user_id)

    Enum.map(@badges, fn badge ->
      current = Map.get(metrics, badge.metric, 0)
      Map.merge(badge, %{
        earned: current >= badge.threshold,
        current: current,
        progress: min(current / badge.threshold, 1.0)
      })
    end)
  end

  def primary(user_id) do
    user_id |> compute() |> Enum.find(& &1.earned)
  end
end
```

### Exibição

**Micro-badge ao lado do username** — em qualquer lugar que o username aparece (comentários, cards de autor, perfil):

```heex
<span :if={badge} class="text-xs" title={badge.name}>{badge.icon}</span>
```

Mostra apenas o badge de maior rank (primeiro earned da lista). Se nenhum earned, não mostra nada.

**Seção "Conquistas" no perfil** — abaixo do grid de stats:

```
Conquistas
🧭 Explorador  ⭐ Curador  💬 Comentarista
🎤 Voz Ativa (cinza)  ❤️ Popular (cinza)  🌟 Estrela (cinza)
```

- Earned: colorido + nome
- Not earned: `opacity-30 grayscale` + nome em ink-400

**Progressão** (só no próprio perfil):

```
🌟 Estrela — 18/25 curtidas recebidas
[████████████░░░░░░] 72%
```

Barra de progresso com `bg-ink-200` track e cor do badge como fill. `text-xs text-ink-500`.

### Performance

3 queries COUNT simples com índice. <5ms cada. Sem cache, sem tabela extra.

---

## 4. Arquitetura de Módulos

### Criar

| Arquivo | Responsabilidade |
|---------|-----------------|
| `lib/o_grupo_de_estudos/engagement/badges.ex` | `compute/1`, `primary/1`, `fetch_metrics/1` (queries de contagem) |

### Modificar

| Arquivo | Mudança |
|---------|---------|
| `engagement.ex` | `liked_step_ids/1`, `list_liked_steps/1`, `total_likes_received/1`, `count_comments_authored/1`, `count_likes_given/2` |
| `collection_live.ex` + template | Like button no step_item + load step_likes em mount |
| `step_live.ex` + template | Like button abaixo do título |
| `community_live.ex` + template | Like button nos step cards |
| `graph_visual_live.ex` | `liked_step_ids` assign + push_event |
| `app.js` | Cytoscape node styling pra liked steps (borda vermelha) |
| `user_profile_live.ex` + template | Grid stats, aba Favoritos, seção Conquistas |
| `comment_thread.ex` | Micro-badge ao lado do username do autor |

---

## 5. Fora de escopo

- Feed de atividade cronológico
- "Quem curtiu" popup
- Destaque semanal
- Notificação "seu passo recebeu X likes"
- Badges persistidos em tabela (calculados on-demand é suficiente pro scale atual)
