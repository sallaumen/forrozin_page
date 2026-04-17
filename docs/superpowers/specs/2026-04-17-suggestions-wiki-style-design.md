# Sugestões de Edição (Wikipedia-style) — Design Spec

**Data:** 2026-04-17
**Status:** Approved
**Sub-projeto:** A da decomposição (B = pontos de atividade, C = exibição de pontos)

---

## Resumo

Transformar o Forrózin numa **Wikipedia de forró roots** — qualquer usuário pode sugerir edições em passos (nome, nota, categoria) e conexões do grafo (criar, remover). Tudo passa por aprovação admin. Contribuidores são reconhecidos publicamente com "last edited by" no passo.

---

## 1. Schema `suggestions`

| Coluna | Tipo | Notas |
|--------|------|-------|
| id | binary_id | PK |
| user_id | binary_id | FK users, NOT NULL — quem sugeriu |
| target_type | string | "step" / "connection" |
| target_id | binary_id | ID do step ou connection |
| action | string | "edit_field" / "create_connection" / "remove_connection" |
| field | string | "name" / "note" / "category_id" (null pra conexões) |
| old_value | text | valor atual (null pra criação) |
| new_value | text | valor proposto (null pra remoção) |
| status | string | "pending" / "approved" / "rejected", default "pending" |
| reviewed_by_id | binary_id | FK users — admin que revisou |
| reviewed_at | naive_datetime | quando foi revisado |
| inserted_at / updated_at | timestamps | |

**Índices:**
- `(status, inserted_at DESC)` — fila de pendentes
- `(user_id, inserted_at DESC)` — "minhas sugestões"
- `(target_type, target_id)` — sugestões por item

---

## 2. Alteração na tabela `steps`

| Coluna nova | Tipo | Notas |
|-------------|------|-------|
| last_edited_by_id | binary_id | FK users, nullable |
| last_edited_at | naive_datetime | nullable |

Preenchidos quando sugestão `edit_field` é aprovada.

---

## 3. Context `Suggestions`

```elixir
# Criar sugestão
Suggestions.create(user, %{
  target_type: "step",
  target_id: step.id,
  action: "edit_field",
  field: "name",
  old_value: "Base Frontal",
  new_value: "Base Frontal Roots"
})

# Aprovar (em transaction: atualiza suggestion + aplica mudança + notifica)
Suggestions.approve(suggestion, admin)

# Rejeitar (atualiza status + notifica)
Suggestions.reject(suggestion, admin)

# Listar
Suggestions.list_pending(opts)           # pra admin, por tipo
Suggestions.list_by_user(user_id, opts)  # pra perfil
Suggestions.count_pending()              # badge no admin nav
```

### Aprovação — transação atômica

```elixir
def approve(suggestion, admin) do
  Multi.new()
  |> Multi.update(:suggestion, Suggestion.review_changeset(suggestion, %{
    status: "approved",
    reviewed_by_id: admin.id,
    reviewed_at: NaiveDateTime.utc_now()
  }))
  |> Multi.run(:apply, fn _repo, %{suggestion: s} ->
    apply_suggestion(s)
  end)
  |> Repo.transaction()
  |> case do
    {:ok, %{suggestion: s}} ->
      Dispatcher.notify(:suggestion_reviewed, s, admin)
      {:ok, s}
    {:error, _, reason, _} ->
      {:error, reason}
  end
end
```

### Aplicar sugestão

```elixir
defp apply_suggestion(%{action: "edit_field"} = s) do
  step = Repo.get!(Step, s.target_id)
  Admin.update_step(step, %{
    String.to_existing_atom(s.field) => s.new_value,
    last_edited_by_id: s.user_id,
    last_edited_at: NaiveDateTime.utc_now()
  })
end

defp apply_suggestion(%{action: "create_connection"} = s) do
  [source_code, target_code] = String.split(s.new_value, "→")
  source = StepQuery.get_by(code: String.trim(source_code))
  target = StepQuery.get_by(code: String.trim(target_code))
  Admin.create_connection(%{source_step_id: source.id, target_step_id: target.id})
end

defp apply_suggestion(%{action: "remove_connection"} = s) do
  Admin.delete_connection(s.target_id)
end
```

---

## 4. UI — Lápis ao lado de cada campo

### Página do passo (`/steps/:code`)

Cada campo editável tem ícone `hero-pencil-square` (w-3.5, text-ink-300, hover:text-accent-orange):

```
BF  Base Frontal 🖊
Nota: "Condutor avança..." 🖊
Categoria: Bases 🖊
```

Ao clicar: input inline com valor pré-preenchido + "Enviar sugestão" + "Cancelar".

### Conexões

Na seção de saídas/entradas:
```
Saídas →
  SC Sacada Simples  [🖊] [×]    ← × sugere remoção
  GP Giro Paulista   [🖊] [×]

[+ Sugerir nova conexão]         ← autocomplete
```

### "Last edited by"

Abaixo do nome/nota, discreto:
```
Última edição por @maria 🧭 · há 3 dias
```
Username linkável + micro-badge. Só aparece se `last_edited_by_id != nil`.

---

## 5. Admin — `/admin/suggestions`

Lista organizada por tipo, com links pros artefatos:

**Seções:**
- Edições de campo (agrupadas por step)
- Novas conexões
- Remoções de conexão

**Cada item:**
- Quem sugeriu (@username linkável)
- O que quer mudar (old → new, com diff visual)
- Link pro passo/grafo
- Botões: Aprovar ✓ / Rejeitar ✗

**Filtros:** status (pendentes/aprovadas/rejeitadas), tipo de sugestão

---

## 6. "Minhas Contribuições" no perfil

Nova aba ou sub-seção no UserProfileLive:

```
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐
│  Passos  │ │Sequências│ │Favoritos ★│ │Contribuições │
└──────────┘ └──────────┘ └──────────┘ └──────────────┘
```

Lista com status:
- 🟡 Pendente — aguardando revisão
- 🟢 Aprovada — aplicada
- 🔴 Rejeitada

---

## 7. Notificações

Novos action types no Dispatcher:
- `"suggestion_approved"` → "Sua sugestão de nome para BF foi aprovada ✓"
- `"suggestion_rejected"` → "Sua sugestão de conexão GP→TR foi rejeitada"

---

## 8. Arquitetura de arquivos

### Criar

| Arquivo | Responsabilidade |
|---------|-----------------|
| `priv/repo/migrations/TIMESTAMP_create_suggestions.exs` | Tabela + índices |
| `priv/repo/migrations/TIMESTAMP_add_last_edited_to_steps.exs` | last_edited_by_id + last_edited_at |
| `lib/o_grupo_de_estudos/suggestions/suggestion.ex` | Schema |
| `lib/o_grupo_de_estudos/suggestions/suggestion_query.ex` | Query reducers |
| `lib/o_grupo_de_estudos/suggestions.ex` | Context (create, approve, reject, list) |
| `lib/o_grupo_de_estudos_web/live/admin_suggestions_live.ex` + template | Página admin |
| `test/o_grupo_de_estudos/suggestions_test.exs` | Tests contexto |
| `test/o_grupo_de_estudos_web/live/admin_suggestions_live_test.exs` | Tests LiveView |

### Modificar

| Arquivo | Mudança |
|---------|---------|
| `step.ex` | Adicionar last_edited_by_id, last_edited_at |
| `step_live.ex` + template | Lápis inline, form sugestão, "last edited by" |
| `router.ex` | Rota `/admin/suggestions` |
| `user_profile_live.ex` + template | Aba Contribuições |
| `dispatcher.ex` | notify(:suggestion_reviewed, ...) |
| `notification.ex` | @valid_actions += suggestion_approved, suggestion_rejected |
| `notifications_live.ex` | action_text pra sugestões |
| `factory.ex` | suggestion factory |
| `top_nav.ex` | Badge de pendentes pra admin |

---

## 9. Fora de escopo

- Sistema de pontos de atividade (Sub-projeto B)
- Anti-spam / rate limiting (Sub-projeto B)
- Ranking / leaderboard (Sub-projeto C)
- Sugestão de passos novos (já existe com suggest_mode)
- Sugestão de links (já existe com step_links + approved flag)
