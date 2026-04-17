# Seguidores — Design Spec

**Data:** 2026-04-17
**Status:** Approved — pronto para implementação

---

## Resumo

Sistema de follow unilateral (sem confirmação) para facilitar navegação social. Sem feed, sem timeline, sem notificação. Puramente utilitário: "quero encontrar meus amigos rápido".

---

## 1. Schema `follows`

| Coluna | Tipo | Notas |
|--------|------|-------|
| id | binary_id | PK |
| follower_id | binary_id | FK users, NOT NULL — quem segue |
| followed_id | binary_id | FK users, NOT NULL — quem é seguido |
| inserted_at | timestamp | sem updated_at |

**Índices:**
- `UNIQUE (follower_id, followed_id)` — um follow por par
- `(followed_id)` — "quem me segue" lookup

**Ecto Schema:**

```elixir
defmodule OGrupoDeEstudos.Engagement.Follow do
  schema "follows" do
    belongs_to :follower, User
    belongs_to :followed, User
    timestamps(updated_at: false)
  end
end
```

---

## 2. API no Engagement context

```elixir
toggle_follow(follower_id, followed_id)   # {:ok, :followed} | {:ok, :unfollowed}
following?(follower_id, followed_id)       # boolean
list_following(user_id, opts \\ [])        # [%User{}] que eu sigo, preloaded
list_followers(user_id, opts \\ [])        # [%User{}] que me seguem, preloaded
count_following(user_id)                   # integer
count_followers(user_id)                   # integer
```

Opts suportam `:search` (filtra por nome/username) e `:preload`.

---

## 3. Aba "Seguidores" na Community

### Tab switcher (3 opções)

```
┌─────────┐ ┌───────────┐ ┌───────────┐
│  Passos │ │Sequências │ │Seguidores │
└─────────┘ └───────────┘ └───────────┘
```

### Layout da aba

**Contadores no topo:**
```
12 seguindo · 8 seguidores
```

**Sub-tabs:**
```
┌──────────┐ ┌───────────┐
│ Seguindo │ │Seguidores │
└──────────┘ └───────────┘
```

**Search bar** — filtra por nome/username.

**Cards de usuário:**
```
┌──────────────────────────────────────┐
│ [Avatar] @username 🧭               │
│          Curitiba, PR               │
│          3 passos · 2 sequências    │
│                         [Seguindo ✓]│
└──────────────────────────────────────┘
```

- Avatar: inicial em círculo
- Username: link → `/users/:username`
- Badge: micro-badge de conquista (via `Badges.primary/1`)
- Localidade: cidade, estado
- Contadores: passos sugeridos + sequências públicas (batch query)
- Botão: "Seguir" (outline) / "Seguindo ✓" (filled accent-orange)

### Carregamento
- Lazy-load ao clicar na aba
- Batch preload de badges
- Contadores via batch query

---

## 4. Botão "Seguir" — onde aparece

### Perfil (`/users/:username`)

Ao lado do nome, visível só quando NÃO é o próprio perfil:

- "Seguir": `bg-accent-orange text-white rounded-full py-1.5 px-5`
- "Seguindo ✓": `bg-transparent border border-accent-orange text-accent-orange rounded-full`
- Toggle sem confirmação

### Community cards de autor

Nos step cards e sequence cards, ao lado do `@username`:

```
@tavano 🧭 [Seguir]
```

Botão mini: `text-xs py-0.5 px-2 rounded-full border`

---

## 5. Grid de stats no perfil — expandido

```
┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
│   23   │ │   12   │ │    5   │ │    8   │ │   12   │
│curtidas│ │favorit.│ │ seqs.  │ │seguindo│ │seguidor│
└────────┘ └────────┘ └────────┘ └────────┘ └────────┘
```

"Seguindo" e "Seguidores" clicáveis → navegam pra community aba Seguidores.

---

## 6. Arquitetura

### Criar

| Arquivo | Responsabilidade |
|---------|-----------------|
| `priv/repo/migrations/TIMESTAMP_create_follows.exs` | Tabela + índices |
| `lib/o_grupo_de_estudos/engagement/follow.ex` | Schema Follow |

### Modificar

| Arquivo | Mudança |
|---------|---------|
| `engagement.ex` | toggle_follow, following?, list/count functions |
| `community_live.ex` + template | Aba Seguidores, sub-tabs, search, cards, botão seguir |
| `user_profile_live.ex` + template | Botão seguir, stats grid expandido |
| `test/support/factory.ex` | Follow factory |
| `test/o_grupo_de_estudos/engagement_test.exs` | Tests de follow |

---

## 7. Fora de escopo

- Notificações de follow
- Feed de atividade dos seguidos
- Timeline algorítmica
- Confirmação de follow (unilateral por design)
- Sugestões de "quem seguir"
