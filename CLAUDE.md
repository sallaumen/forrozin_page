# CLAUDE.md — O grupo de estudos (Forrózin)

Acervo de passos de forró, usado ativamente em aulas em Curitiba. O autor é o Tavano (L. Tatá). Qualidade é obrigatória.

---

## Preferências do dev

Sou engenheiro de software senior de Elixir. Sempre seguir: clean code, DDD, pensamento funcional, arquitetura hexagonal, design estratificado. Todo código novo deve ser feito com TDD, explicando cada decisão por trás dos testes.

---

## Arquivos atuais

**`complete_description.md`** — fonte da verdade. Leia esse arquivo antes de qualquer coisa. Toda a estrutura, convenções, passos e metadados estão documentados lá. São ~156 passos em 19 seções numeradas + convenções + conceitos técnicos + grafo de conexões.

**`index.html`** — site React single-file (42KB) derivado do MD. Usa Babel standalone + React 18. Dados hardcoded em `SECTIONS[]` e imagens referenciadas de `images/`.

**`images/`** — 54 JPGs extraídos do base64 original. Nomeados por código: `HF-XXX.jpg`.

---

## Decisões que não estão óbvias no MD

- "Facão" é nome obsoleto para Inversão — usar **IV**
- "CH", "SSP", "SC-SP" são o mesmo passo — usar **SCSP**
- Nomes em inglês dos passos HF-* são os nomes originais do canal @forro_footwork — **não corrigir sem confirmar**
- Descrições do @forro_footwork: **nunca copiar a legenda diretamente** — reescrever com as próprias palavras
- Seção de "vídeos cortados" (❓) foi removida — era lixo
- Usar sempre "centro de massa" em vez de "CDM" — mais claro e didático
- Centro de massa = região do umbigo. Todo movimento começa com deslocamento do centro de massa. Manter o pé embaixo do centro de massa = equilíbrio.

### Política de visibilidade de passos

Passos com `wip: true` são **restritos** — visíveis apenas a usuários com permissão explícita (admin ou papel futuro "visualizador completo"). Nunca exibir ao público geral. Isso inclui **todos os passos HF-* do @forro_footwork** que ainda não foram integrados com certeza ao vocabulário ensinado. Objetivo: não espalhar desinformação.

### Mecânicas documentadas nas conversas (não estão no MD)

**DA-R:** O condutor executa uma espécie de base estranha (esquerda à frente → centro → direita à frente). A conduzida faz base lateral padrão. Quando o condutor abre para trás no lugar de avançar o pé direito, gera intenção lateral — pode entrar em sacada armada (condução vinda pelos braços, não pela coxa/perna como na intenção de sacada padrão). Abre também para caminhada e chique-chique.

**BE → GPE:** A condução não vem da intenção de sacada pela perna. Vem do tronco, com intensidade crescente quando a perna esquerda avança. A conduzida literalmente não tem outra opção mecânica senão o Giro Paulista Estranho.

**TR-ARM / Elástico:** As barrigas ficam de frente durante o elástico com um leve V. Condutor recua quadril esquerdo, conduzida recua quadril direito — esse V gira. No meio do V, os dois cruzam as pernas pela frente → trava. Marca forte nesse lado, depois condutor volta para trás (padrão das voltas do roots).

---

## Modelo de domínio (extraído do MD)

### Step (Passo)
- `code`: string única (ex: "BF", "HF-SRS", "GP-D")
- `name`: nome em português
- `note`: descrição técnica/mecânica (opcional)
- `wip`: boolean — em treinamento (visível só pra admin)
- `image_path`: opcional, só passos HF-* têm imagem
- `status`: published | draft

### Section (Seção)
- `id`: kebab-case
- `num`: integer 1-19 ou null (convenções, conceitos)
- `title`, `code`, `category`, `description`, `note`
- Tem `items` (steps) diretos e/ou `subsections`

### Categories (11)
sacadas, travas, caminhadas, giros, pescadas, inversao, bases, outros, footwork, conceitos, convencoes — cada uma com cor e label.

### Connection Graph
Steps ligados por entradas/saídas (grafo dirigido). Hub central: "Intenção de Sacada".

### Technical Concepts (7)
Princípios que explicam a mecânica dos passos (não são passos).

---

## Tooling

- **ASDF** para versões: `erlang 26.2.5` + `elixir 1.16.3-otp-26` (`.tool-versions` dentro de `forrozin/`)
- **Docker Compose** para Postgres local (dev + test). Não rodar Postgres direto na máquina.
- **Deploy: Fly.io** — plataforma oficial Phoenix. `fly.toml` gerado por `fly launch`.
- **Dockerfile multi-stage** (builder + runner) para produção.

---

## Plano: migração para Phoenix/Elixir

O projeto Phoenix fica em `forrozin/` (subpasta dentro deste repo).

### Arquitetura — Stratified Design + DDD

Camadas de baixo para cima:
```
[Dados]       Ecto schemas + migrations
[Calculo]     Contextos puros sem efeitos colaterais (Encyclopedia, Authorization)
[Acao]        Contextos com I/O (Accounts, Engagement, Media, Admin)
[Web]         LiveViews + Components + Plugs
```

### Bounded Contexts

| Contexto | Tipo | Responsabilidade |
|----------|------|-----------------|
| **Encyclopedia** | Calculo | Passos, secoes, categorias, conceitos, grafo. Visibilidade por policy. |
| **Authorization** | Calculo | Policy.authorize/3 — regras centralizadas |
| **Accounts** | Acao | Registro, login, sessoes, roles (admin/user). |
| **Engagement** | Acao | Feedback por passo, tracking de visitas, analytics. |
| **Media** | Acao | Animacoes 3D (keyframes JSONB), geracao de video via IA (Runway/Kling), Oban jobs. |
| **Admin** | Acao | Publicar/esconder passos WIP, dashboard com metricas. |

### Schema do Banco (PostgreSQL)

```
-- Migration 1
categories (id, name, label, color)

-- Migration 2: Encyclopedia
sections (id, num, title, code, category_id, description, note, position)
subsections (id, section_id, title, note, position)
steps (id, code, name, note, category_id, status, image_path, wip, position, section_id, subsection_id)
step_connections (id, from_step_id, to_step_id, type [entry|exit])
technical_concepts (id, title, description)
concept_steps (concept_id, step_id)

-- Migration 3: Accounts (gerado por phx.gen.auth)
users (id, email, hashed_password, role [admin|user], confirmed_at, inserted_at, updated_at)
user_tokens (id, user_id, token, context, sent_to, inserted_at)

-- Migration 4: Media
step_animations (id, step_id, keyframes_json, status, inserted_at)
step_videos (id, step_id, provider, provider_job_id, url, status, inserted_at)

-- Migration 5: Engagement
feedbacks (id, user_id, step_id, content, rating, inserted_at)
page_visits (id, path, user_id, ip_hash, inserted_at)
```

### Estrutura do projeto

```
forrozin/
├── .tool-versions
├── docker-compose.yml
├── Dockerfile
├── fly.toml
├── lib/forrozin/
│   ├── encyclopedia/
│   │   ├── encyclopedia.ex        # API publica (calculos puros)
│   │   ├── step.ex, section.ex, subsection.ex, category.ex
│   │   ├── technical_concept.ex, connection.ex
│   │   └── visibility.ex
│   ├── accounts/
│   │   ├── accounts.ex, user.ex, user_token.ex
│   ├── engagement/
│   │   ├── engagement.ex, feedback.ex, page_visit.ex
│   ├── media/
│   │   ├── media.ex, step_animation.ex, step_video.ex
│   │   └── video_generation.ex    # Integracao Runway/Kling via Oban
│   ├── admin/admin.ex
│   └── authorization/policy.ex
├── lib/forrozin_web/
│   ├── live/
│   │   ├── home_live.ex           # Lista de secoes + busca + filtro
│   │   ├── step_live.ex           # Detalhe do passo + 3D + video
│   │   ├── graph_live.ex          # Grafo de conexoes
│   │   ├── accounts/ (login, register)
│   │   └── admin/ (dashboard)
│   ├── components/
│   │   ├── step_card.ex, section_tree.ex
│   │   ├── category_badge.ex, feedback_form.ex
│   │   └── three_canvas.ex        # Wrapper LiveView para Three.js
│   ├── hooks/
│   │   └── three_canvas.js        # Three.js JS hook para LiveView
│   └── plugs/require_admin.ex
├── priv/
│   ├── data/complete_description.md
│   └── repo/seeds.exs + migrations/
└── test/ (espelha lib/, ExMachina factories)
```

### Fases

0. **Setup** — ASDF, `mix phx.new forrozin --live --no-mailer`, Docker Compose, deps (credo, dialyxir, ex_machina), Fly.io.
1. **MVP** — Encyclopedia context + seeds do MD + HomeLive (secoes/busca/filtro). Site identico ao HTML atual.
2. **Auth** — `mix phx.gen.auth`. Roles admin/user. current_user no socket.
3. **Visibilidade + Admin** — Policy.authorize/3. Toggle publicar/esconder WIP. Dashboard admin.
4. **3D Interativo** — Three.js via LiveView JS hook. Schema StepAnimation (keyframes JSONB). Editor admin de joints.
5. **Video IA** — Media.VideoGeneration + Oban. Integracao Runway ML / Kling. Armazenamento Fly Volumes ou S3.
6. **Engagement** — Feedback por passo. Page visits. Grafo visual (Three.js ou D3.js). Cache ETS. Mobile.

### TDD Flow

```
1. Teste unitario falhando (ex: Step.changeset valida code)
2. Implementar minimo pra passar
3. Teste de integracao (ex: Encyclopedia.list_sections retorna hierarquia)
4. Implementar context function
5. Teste de LiveView (ex: HomeLive renderiza secoes)
6. Implementar LiveView usando context
7. Refatorar → commit
```

### Deps

```
phoenix ~> 1.7
phoenix_live_view ~> 0.20
ecto_sql ~> 3.10
postgrex
argon2_elixir ~> 3.0
oban ~> 2.17          # jobs assincronos (geracao de video)
req ~> 0.4            # HTTP client para APIs de IA
ex_machina (test)
credo (dev/test)
dialyxir (dev/test)
```

---

## Proximos passos

1. Atualizar CLAUDE.md (feito)
2. Fase 0: setup do projeto Phoenix (ASDF + mix phx.new + Docker + Fly.io)
3. Fase 1: Encyclopedia MVP com TDD
