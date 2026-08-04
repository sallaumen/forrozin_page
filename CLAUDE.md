# CLAUDE.md - O Grupo de Estudos (ogrupodeestudos.com.br)

Rede social de forro roots para estudo de danca. Usada em aulas em Curitiba pelo professor Tavano (L. Tata). Qualidade premium, nao software preguicoso.

## Regra rigida: codigo em ingles, sempre

**Jamais escrever codigo em portugues. TUDO em ingles**: nomes de modulos, funcoes,
variaveis, atomos, parametros, `@moduledoc`, `@doc`, `@spec`, comentarios, nomes de
teste e `describe`, mensagens de commit de codigo, chaves de assigns, nomes de eventos
LiveView, nomes de tabelas, colunas e indices.

Ficam **em portugues** so o que o usuario le ou o dominio exige:

- Textos de interface (HEEx, e-mails, mensagens de erro exibidas, flash).
- Nomes e descricoes de passos, categorias e conexoes (conteudo do acervo).
- Siglas do forro (IV, SCSP, HF-*), que nunca sao traduzidas.
- O nome do projeto, `OGrupoDeEstudos` / `o_grupo_de_estudos`.

Interface em portugues nao autoriza codigo em portugues. Se um identificador precisa
descrever um termo de dominio, usa-se o equivalente em ingles (`waitlist`, nao
`lista_de_espera`), e o texto exibido continua em portugues.

## Padroes de qualidade

Seguir **todos** os principios de `~/elixir-references/` (Playbook + RFCs). Destaques criticos:

- TDD obrigatorio. Testes primeiro, implementacao depois.
- Nome de teste descreve comportamento, sem "should": `returns X when Y`, `verifies X`.
- Comentario e ultimo recurso. Nome de funcao e de variavel explicam; comentario so
  para o que o codigo nao consegue dizer (motivo, armadilha externa, decisao). Nunca
  comentario dentro de corpo de teste.
- Clean code: funcoes ate 10 linhas (max 18). Uma responsabilidade por funcao.
- Grokking Simplicity: separar calculos (puros) de acoes (I/O). Calculos nao logam.
- Pattern matching sobre condicionais. Multiplas clausulas sobre `if`/`case` internos.
- Pipes comecam com valor bruto, nunca com chamada de funcao.
- `with` para 2+ operacoes que podem falhar. `case` para decisao unica.
- Nunca `@dialyzer {:nowarn_function}` ou Credo ignores. Corrigir a causa raiz.
- Nunca `@tag :skip` em testes. Todo teste passa.
- HEEx: usar `:if={}` no atributo, `<%= if %>` so com `else`.
- Logging inline, nunca funcoes privadas so para logar.
- Nunca usar travessao (em dash) em textos voltados ao usuario. Marca de IA.

## Regras de arquitetura (em vigor desde jul/2026, PRs #139-#150)

- **Triad Context/Schema/Query**: queries em modulos `*Query`, nunca direto no
  contexto nem na camada web. A camada web fala SO com contexto: nada de `Repo.`,
  `import Ecto.Query` nem chamada a modulo `*Query`. A regra e executavel:
  `test/o_grupo_de_estudos_web/architecture_test.exs` falha se violada.
  Contexto delega reads (`defdelegate`) e mantem mutations.
- **Autorizacao na borda**: todo `handle_event` que muda estado passa por
  `Authorization.Policy.authorize/3` (ou `authorized?/3` para flags de UI).
  Nunca checar `is_admin`/`user_id` inline; nunca castar `:role` de params.
- **Contexto so fala com contexto pela API publica**: nunca consultar schema
  de outro contexto (usar as batch APIs: `Encyclopedia.steps_by_ids/1`,
  `Sequences.map_by_ids/1`, `Accounts.list_user_summaries/1`, etc.).
- **Ecto.Enum sobre `:string` + `validate_inclusion`** para todo campo
  enumeravel (coluna continua string no banco). Falta converter:
  `Notification.action/parent_type/target_type`.
- **Timestamps de negocio (`*_at`) em `:utc_datetime`**; `timestamps()`
  (inserted_at/updated_at) seguem naive por decisao consciente.
- **Backfills NUNCA em migrations**: migration so muda schema; backfill vai em
  mix task/release task com streaming. Indice em tabela quente: migration
  propria com `@disable_ddl_transaction` + `concurrently: true` +
  `create_if_not_exists` (template: `20260702120000_add_teacher_student_links_student_index.exs`).
- **Trabalho de boot via Oban** (`Workers.StartupScripts`), nunca Task solta
  com sleep. Admin ids cacheados em `Accounts.AdminIdsCache` (TTL 60s; 0 em teste).

## Stack

- **Elixir 1.19 / OTP 27** (`.tool-versions` na raiz)
- **Phoenix 1.8 + LiveView 1.1** (app: `o_grupo_de_estudos`)
- **Tailwind CSS v4** com `@theme` design tokens, dark mode via `.dark` class
- **PostgreSQL** via Docker Compose
- **Oban** para jobs (email, backups periodicos)
- **Swoosh + gen_smtp** via Brevo
- **Deploy: Fly.io** com volumes para uploads

**ATENCAO**: `fly deploy` builda do filesystem local, NAO do git. Nunca deixar migrations experimentais no disco ao deployar.

## Bounded contexts

| Contexto | Responsabilidade |
|----------|-----------------|
| Encyclopedia | Passos, secoes, categorias, conexoes (grafo), links de video |
| Accounts | Users, auth (argon2), sessoes, dark_mode, is_teacher |
| Engagement | Follows, likes, comments, favorites, notifications, badges, Presence |
| Sequences | Sequencias de passos (gerador, manual builder, validador) |
| Admin | Backups JSON, error_log, suggestions |
| Media | Storage (avatars com Mogrify) |
| Authorization | Policy.authorize/3 |

## Rotas principais

| Rota | Descricao |
|------|-----------|
| `/` | Landing publica |
| `/collection` | Acervo de passos por categoria |
| `/graph/visual` | Mapa interativo (Cytoscape.js) + sequencias |
| `/sequence` | Sequencias da comunidade |
| `/study` | Area professor/aluno |
| `/steps/:code` | Detalhe do passo |
| `/settings` | Perfil, avatar, dark mode |
| `/admin/*` | Backups, links, sugestoes, erros |

## Patterns do projeto

**Macro handlers**: eventos comuns (follow, social bubble, activity toast) injetados via `use` em `handlers/`. Evita duplicacao entre LiveViews.

**NotificationSubscriber hook**: on-mount que carrega contadores, Presence, dark mode.

**Backup system**: snapshots JSON periodicos (Oban) em `priv/backups/`. Restore via `mix o_grupo_de_estudos.restore_backup PATH --clear`.

**Uploads**: `Media.Storage` + `Plugs.UploadsStatic`. NAO usar `static_paths` para uploads.

**Design tokens**: paleta sepia/editorial em `@theme` (ink-50..900, gold, accents). Dark mode inverte a ink scale via CSS variables, zero mudanca em templates.

## Dominio (forro)

- 128 passos catalogados, 11 categorias, grafo dirigido de conexoes
- "Facão" = nome obsoleto para Inversao, usar **IV**
- "CH"/"SSP"/"SC-SP" = mesmo passo, usar **SCSP**
- Passos HF-* sao do canal @forro_footwork. Nomes em ingles sao originais, nao corrigir sem confirmar
- Descricoes do @forro_footwork: nunca copiar legenda, reescrever
- Usar "centro de massa" (nao "CDM"): regiao do umbigo
- Passos `wip: true`: restritos, nunca exibir ao publico

## Regra rigida: a suite nao pode tomar a maquina

O `mix test` roda numa maquina que a pessoa esta usando ao mesmo tempo. O limite
vive no projeto e vale para qualquer um que rode os testes:

- `config/test.exs` define `max_cases` (um quarto dos cores) e o expoe em
  `:test_max_cases`.
- `test/test_helper.exs` derruba os schedulers da VM para o mesmo numero. Sem
  isso o `max_cases` sozinho nao resolve: a BEAM continua espalhando por todos
  os cores.

**Nunca subir esses numeros nem contornar com flag na linha de comando.** Para uma
rodada mais rapida quando a maquina esta livre, `TEST_MAX_CASES=8 mix test`; o CI
usa 16 pela mesma variavel. Rodar a suite inteira so quando precisar: durante o
desenvolvimento, `mix test caminho/do/arquivo_test.exs`.

## Comandos

```bash
docker compose up -d              # Postgres
mix phx.server                    # Dev
mix test                          # Testes (limitado a 1/4 dos cores)
TEST_MAX_CASES=8 mix test         # Mais rapido, quando a maquina esta livre
mix credo && mix dialyzer         # Qualidade
fly deploy -a o-grupo-de-estudos  # Producao
```
