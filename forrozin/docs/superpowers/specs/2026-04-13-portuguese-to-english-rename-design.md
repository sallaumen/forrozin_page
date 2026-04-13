# Design: Portuguese → English Internal Rename

**Date:** 2026-04-13
**Approach:** Big Bang — all changes in one session
**Constraint:** Zero data loss. DB table names stay in Portuguese. User-facing text stays in Portuguese.

---

## Scope

Rename all internal Elixir identifiers (modules, functions, schema fields, file names, routes) from Portuguese to English. DB column names are also renamed via migrations. Enum string values in the DB are updated. User-visible text (step names, notes, category labels, UI copy) is untouched.

The naming is intentionally dance-agnostic (`Step`, `Category`, `Section`, `Connection`) to support future dance styles beyond forró.

---

## Section 1 — Module and File Renames

| Current | New |
|---|---|
| `Forrozin.Enciclopedia` | `Forrozin.Encyclopedia` |
| `Enciclopedia.Passo` | `Encyclopedia.Step` |
| `Enciclopedia.Categoria` | `Encyclopedia.Category` |
| `Enciclopedia.Secao` | `Encyclopedia.Section` |
| `Enciclopedia.Subsecao` | `Encyclopedia.Subsection` |
| `Enciclopedia.Conexao` | `Encyclopedia.Connection` |
| `Enciclopedia.ConceitoTecnico` | `Encyclopedia.TechnicalConcept` |
| `Enciclopedia.Semeador` | `Encyclopedia.Seeder` |
| `Workers.EnviarEmailConfirmacao` | `Workers.SendConfirmationEmail` |
| `Workers.BackupPeriodico` | `Workers.PeriodicBackup` |
| `Emails.ConfirmacaoEmail` | `Emails.ConfirmationEmail` |
| `ForrozinWeb.AcervoLive` | `ForrozinWeb.CollectionLive` |
| `ForrozinWeb.PassoLive` | `ForrozinWeb.StepLive` |
| `ForrozinWeb.GrafoLive` | `ForrozinWeb.GraphLive` |
| `ForrozinWeb.GrafoVisualLive` | `ForrozinWeb.GraphVisualLive` |
| `Mix.Tasks.Forrozin.ExtrairConexoes` | `Mix.Tasks.Forrozin.ExtractConnections` |
| `Mix.Tasks.Forrozin.RestaurarBackup` | `Mix.Tasks.Forrozin.RestoreBackup` |

File renames follow module names (snake_case): `enciclopedia.ex` → `encyclopedia.ex`, `passo.ex` → `step.ex`, `acervo_live.ex` → `collection_live.ex`, etc.

---

## Section 2 — DB Column Renames (via migration) and Enum Value Updates

All column renames use `ALTER TABLE ... RENAME COLUMN` — zero data movement, transactional, instant.
Enum value updates use `UPDATE ... SET col = 'new' WHERE col = 'old'`.

### Column renames

**`passos`**
- `codigo` → `code`
- `nome` → `name`
- `nota` → `note`
- `caminho_imagem` → `image_path`
- `posicao` → `position`
- `categoria_id` → `category_id`
- `secao_id` → `section_id`
- `subsecao_id` → `subsection_id`

**`categorias`**
- `nome` → `name`
- `rotulo` → `label`
- `cor` → `color`

**`secoes`**
- `titulo` → `title`
- `codigo` → `code`
- `descricao` → `description`
- `nota` → `note`
- `posicao` → `position`
- `categoria_id` → `category_id`

**`subsecoes`**
- `titulo` → `title`
- `nota` → `note`
- `posicao` → `position`
- `secao_id` → `section_id`

**`conexoes_passos`**
- `tipo` → `type`
- `rotulo` → `label`
- `descricao` → `description`
- `passo_origem_id` → `source_step_id`
- `passo_destino_id` → `target_step_id`

**`conceitos_tecnicos`**
- `titulo` → `title`
- `descricao` → `description`

**`usuarios`**
- `nome_usuario` → `username`
- `senha_hash` → `password_hash`
- `papel` → `role`

### Enum value updates

| Table | Column | Old | New |
|---|---|---|---|
| `conexoes_passos` | `type` | `saida` | `exit` |
| `conexoes_passos` | `type` | `entrada` | `entry` |
| `passos` | `status` | `publicado` | `published` |
| `passos` | `status` | `rascunho` | `draft` |

### Backup safety

Before migrations run: `backup_20260413_211128.json` (Portuguese fields, current DB state).
After migrations run: restore from `backup_20260413_211128_en.json` (English fields, same data).
Both files are in `priv/backups/`. The EN backup has been validated: 121 steps, 131 connections, all enum values already translated.

---

## Section 3 — Function Renames

### `Forrozin.Encyclopedia` (was `Enciclopedia`)

| Current | New |
|---|---|
| `listar_categorias/0` | `list_categories/0` |
| `buscar_categoria_por_nome/1` | `get_category_by_name/1` |
| `listar_secoes/0` | `list_sections/0` |
| `listar_secoes_com_passos/0` | `list_sections_with_steps/0` |
| `contar_passos_publicos/0` | `count_public_steps/0` |
| `buscar_passo_por_codigo/1` | `get_step_by_code/1` |
| `buscar_passo_com_detalhes/2` | `get_step_with_details/2` |
| `buscar_passos/1` | `search_steps/1` |
| `listar_grafo/1` | `build_graph/1` |
| `listar_todos_passos_mapa/0` | `list_all_steps_map/0` |
| `listar_conceitos_tecnicos/0` | `list_technical_concepts/0` |

### `Forrozin.Accounts`

| Current | New |
|---|---|
| `registrar_usuario/1` | `register_user/1` |
| `confirmar_email/1` | `confirm_email/1` |
| `email_confirmado?/1` | `email_confirmed?/1` |
| `autenticar_usuario/2` | `authenticate_user/2` |
| `buscar_usuario_por_id/1` | `get_user_by_id/1` |

### `Forrozin.Admin`

| Current | New |
|---|---|
| `criar_conexao/1` | `create_connection/1` |
| `editar_conexao/2` | `update_connection/2` |
| `remover_conexao/1` | `delete_connection/1` |

### `Forrozin.Admin.Backup`

| Current | New |
|---|---|
| `criar_backup!/0,1` | `create_backup!/0,1` |
| `restaurar_backup!/1` | `restore_backup!/1` |
| `listar_backups/0,1` | `list_backups/0,1` |

---

## Section 4 — Routes

| Current | New |
|---|---|
| `/entrar` | `/login` |
| `/cadastro` | `/signup` |
| `/confirmar/:token` | `/confirm/:token` |
| `/acervo` | `/collection` |
| `/grafo` | `/graph` |
| `/grafo/visual` | `/graph/visual` |
| `/passos/:codigo` | `/steps/:code` |

---

## What Does NOT Change

- DB table names: `passos`, `categorias`, `secoes`, `subsecoes`, `conexoes_passos`, `conceitos_tecnicos`, `usuarios`, `conceitos_passos` (join)
- User-facing text in templates: step names, notes, category labels, UI copy — all remain in Portuguese
- Step codes (BF, SC, ARM-D, etc.) — domain identifiers, not internal code
- App name `forrozin` — brand, not an internal concept
- `id`, `inserted_at`, `updated_at`, `wip`, `num`, `status` column names — already English or intentionally unchanged
- `papel` values `"admin"` / `"user"` — already English
