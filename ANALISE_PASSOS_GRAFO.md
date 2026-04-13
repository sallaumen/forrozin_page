# Análise Completa de Passos — Plano de Decomposição para o Grafo

**Revisado em:** 2026-04-13 (ajustes do Tatá incorporados)
**Objetivo:** Identificar passos que na verdade são duas entidades (passo A + passo B + aresta nomeada), propor o que remover, o que criar e quais conexões estabelecer. Nada é alterado no banco sem o Tatá presente.

---

## Estado Atual do Semeador

O semeador possui **~155 entradas de passo** espalhadas em **20 seções + convenções**. Dessas:

| Categoria | Quantidade |
|-----------|-----------|
| Passos limpos (manter) | ~88 |
| Compostos óbvios (remover → virar aresta) | 13 |
| Duplicatas exactas (remover) | 4 |
| Candidatos resolvidos (decisão tomada) | 8 |
| Notações/convenções (não são passos, manter) | 9 |
| WIP HF-* (manter, já invisíveis) | 46 |

---

## 1. COMPOSTOS ÓBVIOS — remover e substituir por arestas

---

### 1.1 — Subseção "Entradas no GP" (dentro de Seção 7 – Giro Paulista)

Esta subseção inteira deve ser **removida**. Cada entrada é um passo duplicado ou uma aresta disfarçada.

| Código atual | Nome | Problema | O que fazer |
|---|---|---|---|
| `DA-R` | A partir da dança aberta | **DUPLICATA** — já existe em Seção 10 | Remover daqui. Aresta `DA-R → GP` já documentada |
| `PI-ímpar` | A partir do pião (giros ímpares) | **DUPLICATA PARCIAL** de `PI`. Acento no código problemático | Remover. Aresta `PI → GP` com `descricao: "Apenas giros ímpares (1, 3, 5...)"` |
| `PMB` | A partir do Pimba | **DUPLICATA** — já existe em Seção 18 | Remover daqui. Aresta `PMB → GP` já documentada |
| `TR-ARM` | A partir da trava armada | **DUPLICATA** — já existe em Seção 4 | Remover daqui. Aresta `TR-ARM → GP` já documentada |
| `AB-D` | A partir do abraço lateral direito | **DUPLICATA PARCIAL** de `AB-GP-D` e composto | Remover. Ver decisão final em §3.3 |

**Arestas a garantir após remoção:**
```
DA-R   → GP     (já em extrair_conexoes)
PI     → GP     descricao: "Apenas giros ímpares (1, 3, 5...)" (já em extrair_conexoes)
PMB    → GP     (já em extrair_conexoes)
TR-ARM → GP     (já em extrair_conexoes)
AB-T   → GP-D   rotulo: "Saída para paulista duplo fechado"  ← NOVO (ver §3.3)
```

---

### 1.2 — Subseção "Entradas" do Pião (dentro de Seção 11 – Pião)

| Código atual | Nome | Problema | O que fazer |
|---|---|---|---|
| `PI-AL` | Entrada pós abertura | Descreve entrada no PI, não o PI em si | Remover. Criar arestas `BF → PI`, `BTR → PI` |
| `PI-B` | A partir da base | Mesma situação | Remover. Idem acima |
| `PI-G` | A partir de finais de giro | Descreve entrada após giro | Remover. Arestas `GS → PI`, `GP → PI` já existem |
| `PI` | Genérico | **DUPLICATA EXACTA** — já existe | Remover. `on_conflict: :nothing` silencia, mas é lixo |

**Arestas a garantir:**
```
BF    → PI    ← NOVO
BTR   → PI    ← NOVO
GS    → PI    (já em extrair_conexoes)
GP    → PI    (já em extrair_conexoes)
```

---

### 1.3 — Subseção "DA-R" dentro de Seção 10 — Dança aberta

Os 4 "passos" com código `"DA-R > X"` são saídas disfarçadas de aresta. **Porém**, os movimentos feitos em dança aberta NÃO são os mesmos passos do close embrace — são versões abertas distintas que sempre retornam à DA-R ao final. Portanto a solução **não é conectar DA-R aos passos fechados**, mas sim criar **novos passos** representando as versões abertas, com **arestas bidirecionais** com DA-R.

| Código atual | Nome | O que fazer |
|---|---|---|
| `DA-R > CA` | Saída: Caminhada | Remover. Criar passo `CA-E-DA` + arestas `DA-R ↔ CA-E-DA` |
| `DA-R > TR` | Saída: Trava | Remover. Criar passo `TR-DA` + arestas `DA-R ↔ TR-DA` |
| `DA-R > SCSP` | Saída: Sacada sem peso | Remover. Criar passo `SCSP-DA` + arestas `DA-R ↔ SCSP-DA` |
| `DA-R > footwork` | Saída: Footwork | Remover. Documentar em `nota` do `DA-R` apenas — footwork aberto ainda não tem passo catalogado |

**Novos passos a criar (ver §6):** `CA-E-DA`, `TR-DA`, `SCSP-DA`

**Arestas — bidirecionais:**
```
DA-R  ↔ CA-E-DA   (2 arestas: DA-R → CA-E-DA  +  CA-E-DA → DA-R)
DA-R  ↔ TR-DA     (2 arestas: DA-R → TR-DA    +  TR-DA → DA-R)
DA-R  ↔ SCSP-DA   (2 arestas: DA-R → SCSP-DA  +  SCSP-DA → DA-R)
```

> **Por que bidirecional?** Esses movimentos na dança aberta sempre resolvem de volta para a posição aberta. O retorno não é uma "saída nova" — é a natureza cíclica da dança aberta. Registrar as duas setas torna isso explícito no grafo.

> **Nota sobre `DA-R > footwork`:** As variações de footwork em dança aberta serão catalogadas no futuro à medida que os HF-* saírem do WIP. Por ora, documentar no campo `nota` do passo `DA-R`.

---

### 1.4 — P1: "Passo de giro a partir de abertura esquerda"

| Código | Nome | Análise |
|---|---|---|
| `P1` | Passo de giro a partir de abertura esquerda | A "abertura esquerda" é simplesmente a **base lateral (BL)**. P1 é o paulista mais básico que existe, saindo da BL. |

**Decisão:** Remover `P1`. Criar aresta `BL → GP` (base lateral → giro paulista). Sem criar nenhum passo novo — BL já existe.

```
BL → GP    ← NOVO (o "P1" virou essa aresta)
```

---

### 1.5 — PE-SC-E: "Pescada após sacada de esquerda"

| Código | Nome | Análise |
|---|---|---|
| `PE-SC-E` | Pescada após sacada de esquerda | Composto: SC-E → PE-E-E. Mecanicamente igual a PE-E-E executada de costas. |

**Decisão:** Remover `PE-SC-E`. Criar aresta `SC-E → PE-E-E` com rótulo.

```
SC-E → PE-E-E    rotulo: "Pescada após sacada de esquerda"
                 descricao: "Condutor fica de costas. Pesca esquerda com esquerda."
```

---

### 1.6 — GPS: "Giro paulista da sacada"

| Código | Nome | Análise |
|---|---|---|
| `GPS` | Giro paulista da sacada | Composto: SC → GP. A sacada completa conduz ao paulista sem passar pela intenção. |

**Decisão:** Remover `GPS`. Adicionar rótulo na aresta `SC → GP` já existente.

```
SC → GP    rotulo: "Giro paulista da sacada"
           descricao: "Sacada completa conduzindo ao paulista — distinto da intenção de sacada."
           (aresta já existe; apenas adicionar rotulo via Admin.editar_conexao)
```

---

### 1.7 — SCSP-TE: "Seguido de trava de esquerda"

| Código | Nome | Análise |
|---|---|---|
| `SCSP-TE` | SCSP seguido de trava de esquerda | "Seguido de" = aresta. |

**Decisão:** Remover `SCSP-TE`. Criar aresta `SCSP → TR-E`.

```
SCSP → TR-E    rotulo: "Sacada sem peso saindo para trava esquerda"
               descricao: "Footwork base 2. Pézin esquerdo bate no 1 antes da trava."
```

---

## 2. DUPLICATAS EXACTAS — remover sem substituição

| Código | Onde aparece | Situação no banco |
|---|---|---|
| `DA-R` | Subseção "Entradas no GP" | Silenciado por `on_conflict: :nothing` — nem foi inserido |
| `PMB` | Subseção "Entradas no GP" | Idem |
| `TR-ARM` | Subseção "Entradas no GP" | Idem |
| `PI` | Subseção "Entradas" do Pião | Idem |

Poluem o semeador e confundem quem lê o código. Remover do semeador. Nenhuma migration necessária (nunca foram inseridos).

---

## 3. CANDIDATOS — decisões tomadas

### 3.1 — SC-E-BA: "Sacada de esquerda a partir do balanço"

**Decisão:** Criar passo `BA` (Balanço). Remover `SC-E-BA`. Encadear via arestas.

```
BF   → BA    ← NOVO (o balanço parte da base frontal)
BA   → SC-E  ← NOVO (o balanço leva à sacada de esquerda)
```

O `BA` também servirá como origem dos arrastes — ver §3.5.

**Novo passo `BA`:**
```
codigo: "BA"
nome: "Balanço"
nota: "Balanço lateral a partir da base frontal. Gera intenção para sacada de esquerda
       e para arrastes. Momento de suspensão antes da decisão do movimento seguinte."
categoria: "bases"
secao: 1 (Bases)
wip: false
```

---

### 3.2 — GS-J-GPC: "Juntos — saída para giro paulista de costas"

**Decisão:** Criar passo `GPC`. Remover `GS-J-GPC`. Aresta `GS → GPC`.

**Novo passo `GPC`:**
```
codigo: "GPC"
nome: "Giro paulista de costas"
nota: "Paulista executado com os parceiros de costas um para o outro. Exige mais
       intensidade na condução. Pode ser feito com qualquer mão (esquerda, direita)
       ou com as duas mãos simultaneamente — neste caso, as duas mãos geram
       intensidade para o centro e soltam como um X, criando a rotação. Entrada: GS."
categoria: "giros"
secao: 7 (Giro Paulista)
wip: false
```

```
GS → GPC    rotulo: "Juntos"  ← NOVO
```

---

### 3.3 — AB-GP-D: "Saída para paulista duplo fechado"

**Decisão:** Remover `AB-GP-D`. Criar aresta `AB-T → GP-D`.

> **Nota importante:** O passo `GP-D` (Paulista duplo) **já existe** na Seção 7. O usuário mencionou criar "GP-2x" mas esse conceito já está mapeado como `GP-D`. Nenhum novo passo necessário. O que faltava era apenas a conexão do abraço lateral.

```
AB-T → GP-D    rotulo: "Saída para paulista duplo fechado"  ← NOVO
               descricao: "Do abraço lateral (trocas de lado): puxar pela mão,
                           condutor e conduzida saem para GP-D-F."
```

---

### 3.4 — PE(pd): "Pescada com pé duplo"

**Decisão:** Renomear código para `PE-PD`. Sem arestas novas — o pé duplo é uma variação de entrada, não um passo-origem independente.

---

### 3.5 — ARD-TP e ARE-TP: arrastes com troca rápida

**Decisão:** Remover `ARD-TP` e `ARE-TP`. A "troca rápida" não é um passo — é um micro-ajuste de footwork interno. Manter apenas `ARD` e `ARE`. Conectar os dois entre si (alternância) e conectar a partir da base frontal e do balanço.

```
ARD  ↔ ARE   (bidirecional — arrastes se alternam)
BF   → ARD   ← NOVO
BF   → ARE   ← NOVO
BA   → ARD   ← NOVO (dependente de BA, criado em §3.1)
BA   → ARE   ← NOVO (dependente de BA, criado em §3.1)
```

> **Nomes atualizados no semeador:**
> - `ARD`: "Arraste direita" (remover "diagonal trás dela" do nome — fica mais limpo)
> - `ARE`: "Arraste esquerda"

---

### 3.6 — CA-TZ: "Caminhada cruzada com trava final"

**Decisão:** Manter como passo. A trava final é a posição de chegada da caminhada cruzada, não um passo separado. Criar aresta `CA-TZ → TR-E` para expressar essa relação.

```
CA-TZ → TR-E    ← NOVO (opcional, mas correto)
```

---

### 3.7 — TR-ARM-PE: "Trava armada com pescada"

**Decisão:** Remover `TR-ARM-PE`. O caminho é lido diretamente no grafo como `ARM-D → TR-E → PE-E-E`. O nome histórico fica preservado como rótulo da segunda aresta.

```
ARM-D → TR-E      ← NOVO (a armada também leva à trava esquerda)
TR-E  → PE-E-E   rotulo: "Trava armada com pescada"
                  descricao: "Condutor permanece no lado direito após a armada.
                              Rouba o pé esquerdo da conduzida."  ← NOVO
```

> ARM-D → TR-ARM (conexão principal já planejada) continua existindo. Agora ARM-D também conecta a TR-E, e TR-E → PE-E-E preserva o nome histórico via rótulo.

---

### 3.8 — IV-CT: "Finta pós-inversão"

**Decisão:** Manter como passo — mecânica própria. Criar aresta `IV → IV-CT`.

```
IV → IV-CT    ← NOVO
```

---

## 4. NOTAÇÕES/CONVENÇÕES — manter como estão

Não são passos dançáveis. Invisíveis no grafo e no acervo público. Mantidos para referência didática.

| Código | Nome | Tipo |
|---|---|---|
| `D`, `E`, `F`, `T` | Direções | Direção |
| `pd(ca-fr)`, `pd(fr-ca)` | Pé duplo | Notação de pé |
| `-A`, `-F` | Saídas de paulista | Sufixo |
| `(ginga pausa 3 dupla)` | Exemplo | Notação |
| `(ginga pés rápidos preparação sacada)` | Exemplo | Notação |

---

## 5. CÓDIGOS PROBLEMÁTICOS — precisam de correção

| Código atual | Problema | Ação |
|---|---|---|
| `DA-R > CA`, `DA-R > TR`, `DA-R > SCSP`, `DA-R > footwork` | Espaço, `>`, lowercase | Remover (são compostos — §1.3) |
| `PI-ímpar` | Acento no código | Remover (é composto — §1.1) |
| `PE(pd)` | Parênteses | Renomear: `PE-PD` |
| `SCSP(pdi)-ET-BE` | Parênteses | Renomear: `SCSP-PDI-ET-BE` |
| `pd(ca-fr)`, `pd(fr-ca)` | Parênteses | Manter (são convenções não roteadas) |
| `-A`, `-F` | Hífen inicial | Manter (sufixos notacionais) |
| `(ginga ...)` | Parênteses e espaços | Manter (são exemplos) |

---

## 6. NOVOS PASSOS A CRIAR

| Código | Nome | Seção | Categoria | Nota resumida | Motivo |
|---|---|---|---|---|---|
| `BA` | Balanço | 1 — Bases | bases | Balanço lateral a partir da BF. Origem de SC-E, ARD, ARE. | Decomposição de SC-E-BA, e base para arrastes |
| `CA-E-DA` | Caminhada esquerda na dança aberta | 6 — Caminhadas | caminhadas | Versão aberta da CA-E. Retorna à DA-R. | Decomposição de `DA-R > CA` |
| `TR-DA` | Trava na dança aberta | 4 — Travas | travas | Versão aberta da trava. Retorna à DA-R. | Decomposição de `DA-R > TR` |
| `SCSP-DA` | Sacada sem peso na dança aberta | 3 — Sacada sem peso | sacadas | Versão aberta da SCSP. Retorna à DA-R. | Decomposição de `DA-R > SCSP` |
| `GPC` | Giro paulista de costas | 7 — Giro Paulista | giros | Paulista de costas. Intensidade na condução. Qualquer mão ou dupla (X). | Decomposição de GS-J-GPC |

> **AB-E não é mais necessária** — P1 vira simplesmente BL → GP (ver §1.4).
> **GP-2X não é necessário** — GP-D (Paulista duplo) já existe na Seção 7.

---

## 7. MAPA COMPLETO DE ARESTAS NOVAS

```
# ── Subseção "Entradas no GP" (após remoção) ────────────────────────────────
DA-R   → GP      (já em extrair_conexoes)
PI     → GP      descricao: "Apenas giros ímpares" (já em extrair_conexoes)
PMB    → GP      (já em extrair_conexoes)
TR-ARM → GP      (já em extrair_conexoes)
AB-T   → GP-D    rotulo: "Saída para paulista duplo fechado"              ← NOVO

# ── Subseção "Entradas no Pião" (após remoção) ───────────────────────────────
BF     → PI      ← NOVO
BTR    → PI      ← NOVO
GS     → PI      (já em extrair_conexoes)
GP     → PI      (já em extrair_conexoes)

# ── Dança aberta — bidirecionais (§1.3) ──────────────────────────────────────
DA-R     → CA-E-DA    ← NOVO
CA-E-DA  → DA-R       ← NOVO
DA-R     → TR-DA      ← NOVO
TR-DA    → DA-R       ← NOVO
DA-R     → SCSP-DA    ← NOVO
SCSP-DA  → DA-R       ← NOVO

# ── P1 → BL (§1.4) ───────────────────────────────────────────────────────────
BL     → GP      ← NOVO

# ── PE-SC-E (§1.5) ───────────────────────────────────────────────────────────
SC-E   → PE-E-E  rotulo: "Pescada após sacada de esquerda"
                 descricao: "Condutor fica de costas. Pesca esquerda com esquerda."  ← NOVO

# ── GPS (§1.6) ────────────────────────────────────────────────────────────────
SC     → GP      rotulo: "Giro paulista da sacada"
                 (aresta já existe — ATUALIZAR rótulo via Admin.editar_conexao)

# ── SCSP-TE (§1.7) ───────────────────────────────────────────────────────────
SCSP   → TR-E    rotulo: "Sacada sem peso saindo para trava esquerda"
                 descricao: "Footwork base 2. Pézin esquerdo bate no 1."  ← NOVO

# ── Balanço (§3.1) ───────────────────────────────────────────────────────────
BF     → BA      ← NOVO
BA     → SC-E    ← NOVO

# ── GPC (§3.2) ───────────────────────────────────────────────────────────────
GS     → GPC     rotulo: "Juntos"  ← NOVO

# ── Arrastes (§3.5) ──────────────────────────────────────────────────────────
ARD    → ARE     ← NOVO (bidirecional par 1)
ARE    → ARD     ← NOVO (bidirecional par 2)
BF     → ARD     ← NOVO
BF     → ARE     ← NOVO
BA     → ARD     ← NOVO
BA     → ARE     ← NOVO

# ── TR-ARM-PE decomposição (§3.7) ────────────────────────────────────────────
ARM-D  → TR-E    ← NOVO
TR-E   → PE-E-E  rotulo: "Trava armada com pescada"
                 descricao: "Condutor permanece à direita após armada.
                             Rouba pé esquerdo da conduzida."  ← NOVO

# ── Demais vínculos planejados ────────────────────────────────────────────────
ARM-D  → TR-ARM  ← NOVO (conexão principal da ARM-D)
IV     → IV-CT   ← NOVO
CA-TZ  → TR-E    ← NOVO (opcional)
```

---

## 8. PLANO DE IMPLEMENTAÇÃO — Ordem de execução

### Fase A — Limpeza de duplicatas e compostos simples (sem novos passos)

1. **Semeador:** Remover as 4 duplicatas da subseção "Entradas no GP":
   `DA-R`, `PMB`, `TR-ARM` (nunca inseridas no banco — só limpeza no código),
   `PI-ímpar` (pode ter sido inserida — verificar).

2. **Semeador:** Remover subseção "Entradas" do Pião: `PI-AL`, `PI-B`, `PI-G`, `PI` (duplicata).

3. **Semeador:** Remover subseção DA-R: `DA-R > CA`, `DA-R > TR`, `DA-R > SCSP`, `DA-R > footwork`.

4. **Semeador:** Remover `P1`, `PE-SC-E`, `GPS`, `SCSP-TE`, `GS-J-GPC`, `AB-GP-D`, `SC-E-BA`, `ARD-TP`, `ARE-TP`, `TR-ARM-PE` (todos os compostos resolvidos).

5. **Migration banco:**
   ```sql
   DELETE FROM passos WHERE codigo IN (
     'PI-AL', 'PI-B', 'PI-G', 'PI-ímpar', 'AB-D',
     'DA-R > CA', 'DA-R > TR', 'DA-R > SCSP', 'DA-R > footwork',
     'P1', 'PE-SC-E', 'GPS', 'SCSP-TE', 'GS-J-GPC',
     'AB-GP-D', 'SC-E-BA', 'ARD-TP', 'ARE-TP', 'TR-ARM-PE'
   );
   ```
   > Verificar se cada código existe antes de executar (`SELECT codigo FROM passos WHERE codigo IN (...)`)

6. `mix ecto.reset && mix run priv/repo/seeds.exs` — confirmar semeador limpo.

---

### Fase B — Renomeações de código problemático

7. **Semeador + Migration UPDATE:**
   - `PE(pd)` → `PE-PD`
   - `SCSP(pdi)-ET-BE` → `SCSP-PDI-ET-BE`
   - `ARD`: nome "Arraste direita" (simplificado)
   - `ARE`: nome "Arraste esquerda" (simplificado)

   ```sql
   UPDATE passos SET codigo = 'PE-PD' WHERE codigo = 'PE(pd)';
   UPDATE passos SET codigo = 'SCSP-PDI-ET-BE' WHERE codigo = 'SCSP(pdi)-ET-BE';
   UPDATE passos SET nome = 'Arraste direita' WHERE codigo = 'ARD';
   UPDATE passos SET nome = 'Arraste esquerda' WHERE codigo = 'ARE';
   ```

---

### Fase C — Criação de novos passos

8. **Semeador:** Adicionar na Seção 1 (Bases):
   ```elixir
   %{codigo: "BA", nome: "Balanço",
     nota: "Balanço lateral a partir da base frontal. Gera intenção para sacada de
            esquerda e para arrastes. Momento de suspensão antes da decisão seguinte."}
   ```

9. **Semeador:** Adicionar na Seção 6 (Caminhadas):
   ```elixir
   %{codigo: "CA-E-DA", nome: "Caminhada esquerda na dança aberta",
     nota: "Versão aberta da caminhada esquerda. Executada em DA-R, retorna à DA-R."}
   ```

10. **Semeador:** Adicionar na Seção 4 (Travas):
    ```elixir
    %{codigo: "TR-DA", nome: "Trava na dança aberta",
      nota: "Versão aberta da trava. Executada em DA-R, retorna à DA-R."}
    ```

11. **Semeador:** Adicionar na Seção 3 (SCSP):
    ```elixir
    %{codigo: "SCSP-DA", nome: "Sacada sem peso na dança aberta",
      nota: "Versão aberta da sacada sem peso. Executada em DA-R, retorna à DA-R."}
    ```

12. **Semeador:** Adicionar na Seção 7 (Giro Paulista):
    ```elixir
    %{codigo: "GPC", nome: "Giro paulista de costas",
      nota: "Paulista executado com os parceiros de costas. Exige mais intensidade
             na condução. Pode ser feito com qualquer mão ou com as duas mãos
             simultaneamente — neste caso, as mãos geram intensidade para o centro
             e soltam como um X, criando a rotação. Entrada: GS."}
    ```

13. `mix ecto.reset && mix run priv/repo/seeds.exs` — confirmar todos os novos passos.

---

### Fase D — Criação de arestas via UI admin ou task atualizada

14. **Atualizar `@conexoes` na task `forrozin.extrair_conexoes`:**
    ```elixir
    # Novas arestas a adicionar:
    {"ARM-D", "TR-ARM"},
    {"ARM-D", "TR-E"},
    {"IV", "IV-CT"},
    {"BF", "PI"},
    {"BTR", "PI"},
    {"BF", "BA"},
    {"BA", "SC-E"},
    {"BF", "ARD"},
    {"BF", "ARE"},
    {"BA", "ARD"},
    {"BA", "ARE"},
    {"ARD", "ARE"},
    {"ARE", "ARD"},
    {"BL", "GP"},
    {"AB-T", "GP-D"},
    {"GS", "GPC"},
    {"DA-R", "CA-E-DA"},
    {"CA-E-DA", "DA-R"},
    {"DA-R", "TR-DA"},
    {"TR-DA", "DA-R"},
    {"DA-R", "SCSP-DA"},
    {"SCSP-DA", "DA-R"},
    {"CA-TZ", "TR-E"},
    {"SCSP", "TR-E"},
    {"SC-E", "PE-E-E"},
    {"TR-E", "PE-E-E"},
    ```

15. **Arestas com rótulo** (usar `Admin.editar_conexao` via admin UI no `/grafo`):
    - `SC → GP`: rotulo "Giro paulista da sacada"
    - `SCSP → TR-E`: rotulo "Sacada sem peso saindo para trava esquerda"
    - `SC-E → PE-E-E`: rotulo "Pescada após sacada de esquerda"
    - `TR-E → PE-E-E`: rotulo "Trava armada com pescada"
    - `GS → GPC`: rotulo "Juntos"
    - `AB-T → GP-D`: rotulo "Saída para paulista duplo fechado"

---

## 9. ESTADO FINAL ESPERADO DO GRAFO (passos públicos não-WIP)

```
# BASES (7)
BTR, BF, BFR, BQ, BL, BE, BA (NOVO)

# SACADAS (3)
SC, SC-E, SCxX

# SACADA SEM PESO (6)
SCSP, SCSP-BE, SCSP-PDI-ET-BE, SCSP-TP, SCSP-MD, SCSP-DA (NOVO)

# TRAVAS (6)
TR-E, TR-FS, TR-FC, TR-P3, ARM-D, TR-ARM, TR-DA (NOVO)

# PESCADAS (2)
PE-E-E, PE-PD
(PE-D-D é wip)

# CAMINHADAS (7)
CA-E, CA-F, CA-I, CA-BF, CA-CT, CA-TZ, CA-E-DA (NOVO)

# GIRO PAULISTA (4)
GP, GP-D, GPE, GPC (NOVO)

# INVERSÃO (2)
IV, IV-CT

# PUSH N PULL (3)
PU, PU-V, PU-E-T

# DANÇA ABERTA (2)
DA-R, DA-U-RE
(CA-E-DA, TR-DA, SCSP-DA aparecem nas suas seções originais mas conectados com DA-R)

# PIÃO (2)
PI, PI-INV

# GIROS (11)
GS, GS-TM, GS-AL, GS-ALT, GS-CH, GS-CHO, GS-MC, GS-RCP
GM, GPA, GCH

# ARRASTES (2)  ← era 4, reduziu com remoção dos -TP
ARD, ARE

# MÃO NAS COSTAS (3)
MC-FP, MC-TM, MC-TG

# ABRAÇO LATERAL (4)  ← era 5, AB-GP-D removido
AB-T, AB-VR, AB-RQ, AB-TD

# CADENA (2)
CD-D, CD-E

# OUTROS (4)
CHQ, PMB, CHC, TRD

# TOTAL: ~83 passos dançáveis (sem WIP, sem convenções)
```

---

## 10. RESUMO EXECUTIVO

| Ação | Itens |
|------|-------|
| Passos a **remover** do semeador + banco | 20 |
| Passos a **criar** | 5 (BA, CA-E-DA, TR-DA, SCSP-DA, GPC) |
| Passos a **renomear** (código/nome) | 4 (PE-PD, SCSP-PDI-ET-BE, ARD, ARE) |
| Arestas **novas** a criar | ~28 |
| Arestas **existentes** a rotular | 2 (SC → GP, e outras via UI) |
| Passos **mantidos** sem mudança | ~78 |

---

## 11. IMPACTO NO GRAFO VISUAL

Após a limpeza:
- O grafo perde ~20 nós redundantes/fantasmas
- Ganha ~28 arestas, várias nomeadas, tornando os caminhos legíveis
- **Hubs centrais** ficam evidentes: `GP`, `DA-R`, `SC`, `BF`, `PI`
- **`DA-R` vira um hub bidirecional** — o único nó com arestas de ida E volta claras para seus vizinhos
- **`BA` (Balanço)** aparece como nó intermediário entre bases e arrastes/sacada esquerda
- **`ARM-D`** alimenta tanto `TR-ARM` quanto `TR-E`, com `TR-E → PE-E-E` preservando o nome histórico "Trava armada com pescada" como rótulo de aresta

---

*Nada executado no banco sem o Tatá presente. Cada fase é independente e reversível.*
