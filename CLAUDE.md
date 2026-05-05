# CLAUDE.md - O Grupo de Estudos (ogrupodeestudos.com.br)

Rede social de forro roots para estudo de danca. Usada em aulas em Curitiba pelo professor Tavano (L. Tata). Qualidade premium, nao software preguicoso.

## Padroes de qualidade

Seguir **todos** os principios de `~/.tavano_rfc.txt`. Destaques criticos:

- TDD obrigatorio. Testes primeiro, implementacao depois.
- Clean code: funcoes ate 10 linhas (max 18). Uma responsabilidade por funcao.
- Grokking Simplicity: separar calculos (puros) de acoes (I/O). Calculos nao logam.
- Pattern matching sobre condicionais. Multiplas clausulas sobre `if`/`case` internos.
- Pipes comecam com valor bruto, nunca com chamada de funcao.
- `with` para 2+ operacoes que podem falhar. `case` para decisao unica.
- Nunca `@dialyzer {:nowarn_function}` ou Credo ignores. Corrigir a causa raiz.
- Nunca `@tag :skip` em testes. Todo teste passa.
- HEEx: usar `:if={}` no atributo, `<%= if %>` so com `else`.
- Logging inline, nunca funcoes privadas so para logar.
- Queries em modulos `*Query`, nunca direto no contexto.
- Nunca usar travessao (em dash) em textos voltados ao usuario. Marca de IA.

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
| Media | Storage (avatars com Mogrify), step_animation |
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

## Comandos

```bash
docker compose up -d              # Postgres
mix phx.server                    # Dev
mix test                          # Testes
mix credo && mix dialyzer         # Qualidade
fly deploy -a o-grupo-de-estudos  # Producao
```
