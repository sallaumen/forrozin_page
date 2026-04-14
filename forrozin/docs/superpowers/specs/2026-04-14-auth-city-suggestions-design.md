# Design: Auth simplificado + Cidade/Estado + Sugestão de passos

**Date:** 2026-04-14
**Scope:** 3 features independentes, implementadas na ordem 1 → 2 → 3

---

## Feature 1 — Simplificar auth (auto-confirm)

### Mudança

Em `Accounts.register_user/1`, preencher `confirmed_at` automaticamente no momento do registro. Não chamar o worker `SendConfirmationEmail`. Não deletar o código de confirmação — apenas desativá-lo.

### O que muda

- `register_user/1`: adiciona `confirmed_at: NaiveDateTime.utc_now()` no changeset, remove a chamada ao Oban worker.
- Template de registro: remover menção a "verifique seu email".
- Banner "confirme seu email" na Collection: remover (todos já vêm confirmados).
- `email_confirmed?/1`: continua existindo, retorna true pra todos os novos.

### O que NÃO muda

- O worker `SendConfirmationEmail` continua no codebase (não deletado).
- A rota `/confirm/:token` continua existindo (não quebra links antigos).
- O campo `confirmation_token` continua no schema.

---

## Feature 2 — Cidade/Estado no cadastro

### Schema

Nova migration adiciona à tabela `users`:
- `state` — `string`, 2 caracteres, not null
- `city` — `string`, not null

### Formulário de registro

- **Estado**: `<select>` com os 27 UFs brasileiros, ordenados alfabeticamente.
- **Cidade**: `<input>` com autocomplete client-side. Ao selecionar um estado, filtra as cidades daquele estado.
- **Nota**: texto abaixo dos campos: "No futuro, vamos sugerir professores e contatos na sua região."

### Dados de cidades

- Arquivo JSON estático: `assets/vendor/ibge_cities.json`
- Formato: `{"AC": ["Acrelândia", "Assis Brasil", ...], "SP": ["São Paulo", ...], ...}`
- ~5.570 municípios, ~150KB gzipped.
- Carregado no browser via JS. Filtro client-side — zero queries no banco.

### JS Hook

- `CityAutocomplete` hook no input de cidade.
- Quando o select de estado muda, o hook filtra o JSON e popula um dropdown de sugestões.
- Ao digitar no input, filtra por prefixo (case-insensitive).
- Click numa sugestão preenche o input.

---

## Feature 3 — Sugestão de passos por usuários

### Schema

Nova migration adiciona à tabela `steps`:
- `suggested_by_id` — UUID, nullable, FK → users
- `nil` = passo oficial (criado pelo admin/sistema)
- preenchido = sugestão de um usuário

### Visibilidade

Todos os usuários logados veem passos sugeridos na Collection e no Mapa. Passos sugeridos exibem badge "Sugestão de @username".

### Permissões

| Ação | Autor do passo | Admin | Outro usuário |
|------|---------------|-------|---------------|
| Ver o passo | sim | sim | sim |
| Editar campos (nome, código, nota, categoria, seção) | sim | sim | não |
| Criar/deletar conexões do passo | sim | sim | não |
| Deletar o passo | sim | sim | não |
| Aprovar (tornar oficial) | não | sim | não |

"Aprovar" = admin seta `suggested_by_id = nil`. O passo vira oficial.

### UI — Collection

- **Badge**: passos com `suggested_by_id` mostram "Sugestão de @username" em badge colorido ao lado do nome.
- **Botão de edição no passo**: o autor vê ✏ no seu passo, que abre o drawer em modo edição — sem precisar do toggle global de admin.
- **"Sugerir passo"**: botão visível para todos os logados. Abre form no drawer para criar passo com `suggested_by_id = current_user.id`.
- O form inclui: nome, código sugerido, nota, categoria (select), seção (select).
- Após criar, o passo aparece na Collection com o badge.

### UI — Mapa de Passos

- Passos sugeridos aparecem com **borda tracejada** (dashed) em vez de sólida.
- O badge não aparece no mapa (espaço limitado) — a borda tracejada já comunica "sugestão".

### Admin

- Admin vê todos os passos sugeridos com badge.
- No drawer de um passo sugerido, admin vê botão "Aprovar" que seta `suggested_by_id = nil`.
- Admin pode editar qualquer passo (sugerido ou oficial) como hoje.

---

## O que NÃO muda

- A estrutura de seções, subseções, categorias, conexões — tudo igual.
- O modo de edição do admin — continua existindo para edição global.
- O Mapa de Passos — layout, setores, circles — tudo igual, só adiciona borda tracejada para sugestões.

---

## Ordem de implementação

1. Feature 1 (auto-confirm) — mais simples, desbloqueia fluxo de teste
2. Feature 2 (cidade/estado) — schema + form + JS hook
3. Feature 3 (sugestões) — schema + permissões + UI changes
