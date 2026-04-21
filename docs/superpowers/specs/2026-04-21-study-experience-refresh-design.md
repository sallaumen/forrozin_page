# Study Experience Refresh Design

## Goal

Dar uma repaginada forte na página `Estudos` para que ela:

- incentive o uso rápido do diário pessoal
- conecte melhor professores, alunos e diários compartilhados
- pareça parte importante do produto, sem virar uma vitrine exagerada
- fique mais elegante tanto no navegador quanto no app

## Product Direction

A página deve seguir uma lógica **hybrid**:

- o **diário pessoal de hoje** continua sendo a ação principal
- a **atividade compartilhada** com professor/aluno sobe visualmente quando houver movimento relevante
- a tela precisa sugerir hábito, continuidade e vínculo, não “gestão de tarefas”

Em outras palavras: a pessoa entra para escrever rápido no próprio diário, mas o sistema puxa naturalmente os diários compartilhados quando há algo vivo para ver ou responder.

## Core UX Principles

### 1. Diário pessoal primeiro

O topo da página deve convidar a escrever imediatamente. A pessoa não pode precisar “decifrar a tela” antes de registrar o estudo do dia.

### 2. Movimento compartilhado visível

Quando houver nota nova de professor/aluno, diário conjunto já aberto no dia, ou interação recente, isso precisa aparecer perto do topo como atividade importante.

### 3. Relações de estudo vivas

A página não deve mostrar professores e alunos como uma lista fria. Ela precisa mostrar quem está ativo, quem deixou nota e qual vínculo vale abrir agora.

### 4. Histórico com significado

O histórico não deve ser só uma dobra de datas. Ele precisa dar contexto: preview da nota, passos vinculados e indicação de atividade conjunta naquele dia.

### 5. Navegação conectada com o resto do produto

Sempre que o nome de uma pessoa aparecer como entidade principal em `Estudos`, ele deve continuar clicável para levar ao perfil da pessoa. A área de estudos não deve virar uma ilha.

## Information Hierarchy

## Web

### Top area

1. título da área
2. resumo leve de constância (`2 registros esta semana`, por exemplo)
3. estado do dia (`Registrado hoje`, `Sem registro ainda`, etc.)

### Main column

O bloco mais forte da página:

- `Diário de hoje`
- textarea mais convidativa
- microcopy de reflexão leve
- passos vinculados logo abaixo

### Secondary column

Bloco de `Movimento` com prioridade alta:

- professor deixou nota hoje
- diário conjunto com atividade nova
- aluno sem resposta recente
- CTA curto como `Abrir diário`

Logo abaixo:

- `Pessoas de estudo`
- professores e alunos com estado mais útil que só nome

### Lower area

`Histórico vivo`

Cada item deve poder mostrar:

- data
- preview da nota
- passos vinculados
- indicação de que houve diário compartilhado naquele dia

## App

No app a ordem muda, mas a lógica é a mesma:

1. Diário de hoje
2. Movimento
3. Professores / alunos
4. Histórico

O app deve privilegiar toque rápido e leitura direta. Nada muito espalhado, mas também sem parecer uma coluna de cards genéricos.

## Visual Direction

### Tone

A estética deve sair do “painel bobinho” e ir para algo mais caloroso, editorial e com sensação de prática real:

- bom respiro
- melhor hierarquia tipográfica
- cartões com papéis diferentes, não todos com o mesmo peso
- blocos de atividade com mais personalidade
- cores suaves de status, sem excesso de alertas

### Component Roles

- `Diário de hoje`: bloco principal, mais amplo, mais respirado
- `Movimento`: bloco compacto, chamando para ação
- `Pessoas de estudo`: bloco relacional
- `Histórico`: bloco de memória/continuidade

## Suggested New UX Features

Estas melhorias são desejáveis porque aumentam uso sem transformar a tela em propaganda:

### Activity cues

- selo quando já existe diário conjunto hoje
- indicação de `professor deixou nota`
- indicação de `última atualização`

### Lightweight reminders

- notificação quando professor ou aluno atualizar o diário compartilhado
- lembrete suave de abrir o diário conjunto quando houver nova atividade

### Habit framing

- pequeno resumo semanal (`2 registros esta semana`)
- estado do dia mais rico que só “registrado”

### Relationship utility

Para professores:

- alunos com movimento hoje
- alunos sem registro recente
- pedidos pendentes mais úteis visualmente

Para alunos:

- professor com nota nova
- professor mais ativo no momento

## Interaction Rules

- o diário pessoal deve estar sempre acessível sem clique extra
- atividade compartilhada relevante deve ficar acima da dobra quando existir
- CTA principal de cada bloco deve ser curto e inequívoco
- nomes de professores/alunos devem continuar navegando para seus perfis

## Scope For Implementation

### In scope

- nova hierarquia visual da home de `Estudos`
- refinamento visual da tela compartilhada quando necessário para manter consistência
- melhor tratamento de estados de atividade
- reforço de links para perfis
- ajustes para web e app

### Out of scope for this pass

- sistema novo de notificações complexas além do que já existir
- analytics pesado
- mudanças profundas no modelo de dados
- gamificação explícita

## Validation

### Automated

- testes LiveView para novos ganchos estruturais e links importantes
- checagem de comportamento para nomes clicáveis

### Manual

- validar a home `Estudos` no navegador e no app
- confirmar que o diário pessoal continua sendo a ação mais fácil
- confirmar que atividade compartilhada ganha visibilidade quando existir
- confirmar que nomes de pessoas levam ao perfil corretamente
