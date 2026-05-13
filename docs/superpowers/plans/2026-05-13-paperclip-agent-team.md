# Paperclip Agent Team Setup — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install Paperclip AI, configure 5 agents (CEO, PM, UI/UX, Backend, QA) with version-controlled system prompts, set up governance, and launch the badges refinement pilot.

**Architecture:** Paperclip runs locally (localhost:3100) as orchestration layer with dashboard, budget tracking, and governance. Each agent uses the `claude-local` adapter to spawn Claude Code sessions using the existing Max subscription auth. System prompts are version-controlled in `docs/paperclip/prompts/` and pasted into the Paperclip UI.

**Tech Stack:** Paperclip AI (Node.js), Claude Code (claude-local adapter), pnpm

---

## File Structure

```
docs/paperclip/
  prompts/
    core.md          -- Shared context block (all agents receive this)
    ceo.md           -- CEO full prompt (core + CEO complement)
    pm.md            -- PM full prompt (core + PM complement)
    ui-ux.md         -- UI/UX full prompt (core + UI/UX complement)
    backend.md       -- Backend full prompt (core + Backend complement)
    qa.md            -- QA full prompt (core + QA complement + RFC ref)
```

These files are the **source of truth** for agent system prompts. When
updating a prompt, edit the file first, then update in the Paperclip UI.

---

### Task 1: Install Prerequisites

**Files:** None (system-level installs)

- [ ] **Step 1: Verify Node.js version**

Run: `node -v`
Expected: `v20.x` or higher (current: v21.6.2 — OK)

- [ ] **Step 2: Install pnpm**

```bash
npm install -g pnpm
```

- [ ] **Step 3: Verify pnpm version**

Run: `pnpm -v`
Expected: `9.15` or higher

- [ ] **Step 4: Verify Claude Code auth**

Run: `claude --version`
Expected: Version output confirming CLI is installed and authenticated.
The Max subscription auth is used by the claude-local adapter.

---

### Task 2: Install Paperclip

**Files:** None (installs in its own directory)

- [ ] **Step 1: Run the Paperclip onboard command**

```bash
npx paperclipai onboard --yes
```

This command:
- Clones the Paperclip repo
- Installs dependencies via pnpm
- Creates an embedded Postgres (PGlite) — separate from project Docker
- Runs migrations
- Starts API server + UI at http://localhost:3100

Wait for it to finish. It takes a few minutes on first run.

- [ ] **Step 2: Verify Paperclip is running**

Open http://localhost:3100 in a browser.
Expected: Paperclip dashboard loads with onboarding screen.

- [ ] **Step 3: Note the startup command for future sessions**

After the first onboard, use this to start Paperclip:

```bash
npx paperclipai run
```

This starts faster and includes self-healing.

---

### Task 3: Create System Prompt Files

**Files:**
- Create: `docs/paperclip/prompts/core.md`
- Create: `docs/paperclip/prompts/ceo.md`
- Create: `docs/paperclip/prompts/pm.md`
- Create: `docs/paperclip/prompts/ui-ux.md`
- Create: `docs/paperclip/prompts/backend.md`
- Create: `docs/paperclip/prompts/qa.md`

These files are the version-controlled source of truth for each agent's
system prompt. Each agent file contains the core block + its complement.

- [ ] **Step 1: Create the core prompt file**

Create `docs/paperclip/prompts/core.md`:

```markdown
# Core Context — Forrozin Studio

All agents receive this block as the foundation of their system prompt.

---

== PROJETO ==
Forrozin (ogrupodeestudos.com.br) — rede social de forro roots para
estudo de danca. Usado em aulas em Curitiba pelo professor Tavano.
Qualidade premium, nao software preguicoso.

== STACK ==
Elixir 1.19 / OTP 27, Phoenix 1.8 + LiveView 1.1, Tailwind CSS v4,
PostgreSQL, Oban, Deploy Fly.io

== BOUNDED CONTEXTS ==
Encyclopedia (passos, grafo), Accounts (auth, users),
Engagement (follows, likes, comments, badges), Sequences (gerador),
Admin (backups), Media (uploads), Authorization (policies)

== PRINCIPIOS INEGOCIAVEIS ==
- TDD obrigatorio. Testes primeiro, implementacao depois.
- Clean code: funcoes ate 10 linhas (max 18).
- Grokking Simplicity: separar calculos (puros) de acoes (I/O).
- Pattern matching sobre condicionais.
- Nunca em-dash em textos ao usuario.
- YAGNI: so o que foi pedido, nada mais.

== HUMILDADE NO DOMINIO DE FORRO ==
Voce NAO e especialista em danca. O Tavano (board) e a autoridade.
PARE e pergunte ao board quando encontrar:
- Nomenclatura de passos incerta
- Conexoes entre passos (qual liga em qual e por que)
- Mecanica corporal ou descricoes de movimento
- Decisoes pedagogicas (progressao, dificuldade)
- Terminologia com possiveis significados regionais
- Qualquer afirmacao sobre "como se danca" algo
Nunca invente teoria de danca. Na duvida, pergunte.
Voce PODE usar sem perguntar:
- Dados factuais do sistema (nomes cadastrados, codigos, categorias)
- Informacoes documentadas no CLAUDE.md
```

- [ ] **Step 2: Create the CEO prompt file**

Create `docs/paperclip/prompts/ceo.md`:

```markdown
# CEO — O Maestro

## Core Context
[Paste full content of core.md here]

## Role
Seu papel: decompor goals em issues, delegar, mediar debates.
Nunca escreva codigo. Nunca opine em detalhes de implementacao.
Resolva conflitos priorizando: simplicidade > elegancia > completude.
Se o debate nao convergir em 3 rodadas, escale pro board.

## Workflow
1. Receba goals do board
2. Decomponha em 1-3 issues com descricoes claras
3. Delegue: requisitos para PM, depois UI/UX e Backend em paralelo
4. Medie o debate (3 rodadas: propostas, criticas, convergencia)
5. Consolide a proposta unificada e envie para QA
6. Se QA rejeitar, coordene nova rodada com o feedback
7. Se nao convergir, escale pro board com resumo do impasse
```

- [ ] **Step 3: Create the PM prompt file**

Create `docs/paperclip/prompts/pm.md`:

```markdown
# PM — O Advogado do Usuario

## Core Context
[Paste full content of core.md here]

## Role
Seu papel: refinar requisitos, user stories, criterios de aceitacao.
Opiniao forte: "Se o aluno nao entende em 3 segundos, esta errado."
Personas: professor Tavano (power user), alunos iniciantes (mobile,
pouca experiencia tech), comunidade de forro (engajamento social).
Pense mobile-first. Pense em quem mal sabe usar celular.

## Output Format
Para cada issue, produza:
1. User story: "Como [persona], quero [acao] para [beneficio]"
2. Criterios de aceitacao (lista numerada, testaveis)
3. Edge cases identificados
4. Perguntas ao board (se houver duvidas de dominio de forro)
```

- [ ] **Step 4: Create the UI/UX prompt file**

Create `docs/paperclip/prompts/ui-ux.md`:

```markdown
# UI/UX — O Esteta Editorial

## Core Context
[Paste full content of core.md here]

## Role
Seu papel: propor layouts, criticar densidade, sugerir interacoes.
Opiniao forte: "Menos pixels, mais significado."
Design tokens: paleta sepia/editorial (ink-50..900, gold, accents).
Dark mode via classe .dark (inverte ink scale, zero mudanca em templates).
HEEx: usar :if={} no atributo. <%= if %> so com else.
Tailwind CSS v4 com @theme. Nunca em-dash.
Progressive disclosure sobre information dump.

## Output Format
Para cada proposta, inclua:
1. Descricao da abordagem visual (hierarquia, espaco, interacao)
2. Componentes Tailwind (classes concretas, nao abstratas)
3. Comportamento mobile vs desktop
4. Impacto em dark mode
5. Critica ao que existe (se aplicavel)
```

- [ ] **Step 5: Create the Backend prompt file**

Create `docs/paperclip/prompts/backend.md`:

```markdown
# Backend — O Engenheiro Funcional

## Core Context
[Paste full content of core.md here]

## Role
Seu papel: propor schemas, contexts, queries, arquitetura.
Opiniao forte: "3 linhas repetidas > abstracao prematura."
Pipes comecam com valor bruto, nunca com chamada de funcao.
with para 2+ operacoes faliveis. case para decisao unica.
Queries em modulos *Query, nunca no contexto.
get_* retorna valor/nil. fetch_* retorna {:ok, v}/{:error, r}.
Funcoes ate 10 linhas. Pattern matching sobre if/case interno.
Logging inline, nunca funcoes privadas so para logar.

## Output Format
Para cada proposta, inclua:
1. Schema changes (se houver)
2. Query module (se houver)
3. Context functions (assinaturas + logica)
4. LiveView assigns impactados
5. Analise de performance (queries, N+1, caching)
```

- [ ] **Step 6: Create the QA prompt file**

Create `docs/paperclip/prompts/qa.md`:

```markdown
# QA — O Guardiao do RFC

## Core Context
[Paste full content of core.md here]

## Role
Seu papel: ultimo gate antes do board. Nada passa sem sua aprovacao.
Opiniao forte: "Sem teste, nao existe."
Voce tem acesso ao tavano_rfc.txt COMPLETO.
Valide TODA proposta contra TODOS os padroes.

## Checklist de Validacao
Para cada proposta, valide:
- [ ] TDD: testes escritos antes da implementacao?
- [ ] Clean code: funcoes <= 10 linhas (max 18)?
- [ ] Grokking Simplicity: calculos puros separados de acoes?
- [ ] Pattern matching sobre condicionais?
- [ ] Pipes comecam com valor bruto?
- [ ] with/case usados corretamente?
- [ ] Sem @tag :skip em testes?
- [ ] Sem Credo ignores?
- [ ] Sem @dialyzer {:nowarn_function}?
- [ ] Queries em modulos *Query?
- [ ] HEEx: :if={} em atributos?
- [ ] Sem em-dash em textos ao usuario?
- [ ] Criterios de aceitacao sao testaveis?
- [ ] Testes existentes continuam passando?

## Output Format
1. APROVADO ou REJEITADO
2. Se rejeitado: lista de violacoes com citacao do RFC
3. Sugestoes de como corrigir cada violacao

## Reference
O arquivo ~/.tavano_rfc.txt contem os padroes completos (2284 linhas).
Consulte-o para qualquer duvida sobre padroes de codigo.
```

- [ ] **Step 7: Commit the prompt files**

```bash
git add -f docs/paperclip/prompts/*.md
git commit -m "docs: version-controlled system prompts for Paperclip agents"
```

---

### Task 4: Create Company and CEO Agent

**Files:** None (Paperclip UI configuration)

Paperclip must be running at http://localhost:3100 for these steps.

- [ ] **Step 1: Create the company**

In the Paperclip dashboard (http://localhost:3100):
1. Click "Create Company" (or equivalent onboarding button)
2. Company name: `Forrozin Studio`
3. Working directory: `/Users/tavano/projects/personal/forrozin_page`

Note the `company-id` shown in the URL or settings — you need it for
the CLI commands below.

- [ ] **Step 2: Create the CEO agent in the dashboard**

In the Paperclip dashboard, inside "Forrozin Studio":
1. Add new agent
2. Name: `maestro`
3. Title: `CEO`
4. Adapter: `claude-local`
5. Model: `opus` (Claude Opus)
6. System prompt: copy full content of `docs/paperclip/prompts/ceo.md`
7. Reports to: Board (no manager — this is the top agent)

- [ ] **Step 3: Configure the CEO adapter via CLI**

```bash
npx paperclipai agent local-cli maestro --company-id <COMPANY_ID>
```

Replace `<COMPANY_ID>` with the ID from Step 1.

This command:
- Installs Paperclip skills in `~/.claude/skills`
- Creates an agent API key for the CEO
- Prints shell exports (PAPERCLIP_AGENT_KEY, etc.)

Expected: success message with environment variables printed.

- [ ] **Step 4: Verify the CEO agent**

In the Paperclip dashboard:
1. Navigate to the CEO agent page
2. Click "Test Environment" (or equivalent validation button)
3. Expected: adapter configuration is valid, agent can authenticate

---

### Task 5: Create Specialist Agents (PM, UI/UX, Backend, QA)

**Files:** None (Paperclip UI configuration)

- [ ] **Step 1: Create the PM agent**

In the Paperclip dashboard, inside "Forrozin Studio":
1. Add new agent
2. Name: `pm`
3. Title: `PM — Advogado do Usuario`
4. Adapter: `claude-local`
5. Model: `sonnet` (Claude Sonnet)
6. System prompt: copy full content of `docs/paperclip/prompts/pm.md`
7. Reports to: `maestro` (CEO)

Then in terminal:
```bash
npx paperclipai agent local-cli pm --company-id <COMPANY_ID>
```

- [ ] **Step 2: Create the UI/UX agent**

In the Paperclip dashboard:
1. Add new agent
2. Name: `uiux`
3. Title: `UI/UX — Esteta Editorial`
4. Adapter: `claude-local`
5. Model: `sonnet` (Claude Sonnet)
6. System prompt: copy full content of `docs/paperclip/prompts/ui-ux.md`
7. Reports to: `maestro` (CEO)

Then in terminal:
```bash
npx paperclipai agent local-cli uiux --company-id <COMPANY_ID>
```

- [ ] **Step 3: Create the Backend agent**

In the Paperclip dashboard:
1. Add new agent
2. Name: `backend`
3. Title: `Backend — Engenheiro Funcional`
4. Adapter: `claude-local`
5. Model: `sonnet` (Claude Sonnet)
6. System prompt: copy full content of `docs/paperclip/prompts/backend.md`
7. Reports to: `maestro` (CEO)

Then in terminal:
```bash
npx paperclipai agent local-cli backend --company-id <COMPANY_ID>
```

- [ ] **Step 4: Create the QA agent**

In the Paperclip dashboard:
1. Add new agent
2. Name: `qa`
3. Title: `QA — Guardiao do RFC`
4. Adapter: `claude-local`
5. Model: `sonnet` (Claude Sonnet)
6. System prompt: copy full content of `docs/paperclip/prompts/qa.md`
7. Reports to: `maestro` (CEO)

Then in terminal:
```bash
npx paperclipai agent local-cli qa --company-id <COMPANY_ID>
```

- [ ] **Step 5: Verify the org chart**

In the Paperclip dashboard:
1. Navigate to the company overview / org chart
2. Verify structure:
   - Board (Tavano) at top
   - maestro (CEO) reporting to Board
   - pm, uiux, backend, qa all reporting to maestro
3. All 5 agents show "Active" status

---

### Task 6: Configure Governance and Budget

**Files:** None (Paperclip UI configuration)

- [ ] **Step 1: Set execution policy**

In the Paperclip dashboard, company settings:
1. Find "Execution Policies" or "Governance" section
2. Set: Board approval required before any code execution
3. This means: when an agent wants to write/modify files, the action
   queues for your approval in the dashboard

- [ ] **Step 2: Set budget limits**

In the Paperclip dashboard, company settings:
1. Find "Budget" section
2. Set conservative daily limits per agent:
   - maestro (Opus): ~$5/day (CEO does less work but uses expensive model)
   - pm (Sonnet): ~$3/day
   - uiux (Sonnet): ~$3/day
   - backend (Sonnet): ~$5/day (most implementation work)
   - qa (Sonnet): ~$3/day
3. Set warning threshold at 80% of daily limit
4. Enable hard-stop: pause agent when budget exceeded

These are conservative starting points. Adjust after observing the pilot.

- [ ] **Step 3: Set CEO heartbeat to manual**

In the Paperclip dashboard, maestro agent settings:
1. Find "Schedule" or "Heartbeat" section
2. Set to: Manual trigger (no automatic heartbeat)
3. This means: the CEO only runs when you trigger it from the dashboard

Later, after validating the flow works, change to 30-minute heartbeat.

- [ ] **Step 4: Verify governance**

In the Paperclip dashboard:
1. Check the governance summary shows board approval enabled
2. Check budget limits are set for all agents
3. Check CEO heartbeat shows "Manual"

---

### Task 7: Smoke Test

**Files:** None (Paperclip UI interaction)

- [ ] **Step 1: Create a trivial test goal**

In the Paperclip dashboard:
1. Create a new Goal in "Forrozin Studio"
2. Title: `Smoke test: verificar fluxo basico`
3. Description: `Objetivo simples para validar que os agentes conseguem
   se comunicar. CEO deve decompor em uma issue e delegar pro PM. PM
   deve responder com um paragrafo confirmando que recebeu e entendeu.`

- [ ] **Step 2: Trigger the CEO manually**

In the Paperclip dashboard:
1. Navigate to the maestro agent
2. Click "Run" or "Trigger Heartbeat" (manual trigger)
3. Watch the execution log in real-time

Expected: CEO reads the goal, creates an issue, and assigns it to PM.

- [ ] **Step 3: Verify PM receives and responds**

In the Paperclip dashboard:
1. Check that the PM agent was triggered (either automatically or
   trigger manually)
2. Read the PM's response in the issue

Expected: PM responds acknowledging the task.

- [ ] **Step 4: Check audit log**

In the Paperclip dashboard:
1. Navigate to "Audit Log" or "Activity"
2. Verify entries for: CEO run, issue created, PM run, PM response
3. Check cost tracking shows token usage for both agents

If any step fails: check the agent's adapter configuration, verify
claude-local is properly set up (Task 4 Step 3), and check that
Claude Code auth is working.

- [ ] **Step 5: Clean up smoke test**

In the Paperclip dashboard:
1. Mark the smoke test goal as completed/archived
2. This keeps the dashboard clean for the real pilot

---

### Task 8: Launch Badges Refinement Pilot

**Files:** None (Paperclip UI interaction — agents produce output in issues)

- [ ] **Step 1: Create the pilot goal**

In the Paperclip dashboard:
1. Create a new Goal in "Forrozin Studio"
2. Title: `Refinar secao de Conquistas no perfil`
3. Description:

```
A secao "Conquistas" no perfil do usuario ocupa espaco demais e
e visualmente chamativa. Precisa ser refinada.

Estado atual:
- 6 badges computados on-demand (sem persistencia no banco)
- No perfil: pills de badges conquistados (com glow laranja)
  + barras de progresso dos nao conquistados (40% opacity)
- No perfil proprio: barras de progresso adicionam ~120px
- Arquivo: lib/o_grupo_de_estudos_web/live/user_profile_live.html.heex
  linhas 309-354
- Modulo: lib/o_grupo_de_estudos/engagement/badges.ex
- Testes: test/o_grupo_de_estudos/engagement/badges_test.exs

Objetivo:
- Reduzir espaco visual da secao
- Deixar menos chamativo (menos "in your face")
- NAO perder informacao de progresso (o usuario precisa saber
  como esta avancando)
- Manter todos os testes existentes passando
- Funcionar em mobile e dark mode

Restricoes:
- Nao mudar a logica de computacao dos badges (badges.ex)
- Nao adicionar persistencia ao banco
- Manter compatibilidade com o micro-badge nos comment threads
```

- [ ] **Step 2: Trigger CEO to start the cycle**

In the Paperclip dashboard:
1. Navigate to the maestro agent
2. Click "Run" / "Trigger Heartbeat"
3. Watch: CEO should decompose the goal into issues and delegate
   the first one (requisitos) to PM

- [ ] **Step 3: Monitor the debate flow**

In the Paperclip dashboard, watch the issue progression:

1. **PM phase**: PM writes user stories and criteria. If PM asks about
   forro domain questions (needs-board-input), answer in the issue.
2. **Debate phase**: CEO delegates to UI/UX and Backend. Watch for:
   - Rodada 1: independent proposals from UI/UX and Backend
   - Rodada 2: cross-critique (each reviews the other's proposal)
   - Rodada 3: CEO consolidates
3. **QA phase**: QA validates the consolidated proposal against RFC
4. **Board approval**: You review the final proposal in the dashboard

At each step, the dashboard should show the agent's output and any
pending approvals for you.

- [ ] **Step 4: Review and approve (or send back)**

When the final proposal reaches Board Approval:
1. Read the consolidated proposal carefully
2. Check: does it solve the problem (less space, less flashy)?
3. Check: does it preserve progress information?
4. Check: is it feasible with the current codebase?
5. Approve if satisfied, or reject with feedback for another round

- [ ] **Step 5: Document learnings**

After the pilot completes (whether approved or after iterations):
1. Note what worked well in the agent interactions
2. Note what needs adjustment (prompts too verbose? too quiet? wrong
   focus?)
3. Note the actual cost (tokens/dollars) for this cycle
4. Decide whether to adjust heartbeat, budget, or agent prompts

This information informs whether to keep manual heartbeat or move to
the 30-minute automated cycle.
