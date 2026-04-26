# Collection Editorial Grid Design

## Goal

Repaginar a página `Collection` para que ela deixe de parecer uma lista técnica e passe a funcionar como um acervo visual, explorável e acolhedor, bonito tanto no navegador quanto no app, sem perder:

- a busca
- os filtros
- o fluxo de sugerir passos
- o reaproveitamento da estrutura real do banco

## Current Problems

Hoje a `Collection` tem uma base funcional boa, mas transmite uma sensação de wiki/lista:

- texto demais na primeira dobra
- pouca presença visual
- hierarquia muito uniforme entre seções, passos e controles
- descoberta mais racional do que sensorial
- tela central ainda “colunar” demais no desktop
- mobile funcional, mas pouco encantador

Além disso, a solução precisa escalar com a comunidade:

- novos passos serão adicionados com frequência
- algumas famílias podem crescer muito mais que outras
- a interface não pode virar uma nova “listona” conforme a base evolui

## Design Principles

### 1. Bonito de verdade, não só organizado

A tela deve parecer um acervo vivo e bem cuidado, não apenas uma coleção de linhas arrumadas.

### 2. Exploração em camadas

A pessoa não deve ser jogada direto em uma lista longa. Ela começa em um nível macro mais claro e visual, e aprofunda gradualmente.

### 3. Sem estrutura paralela fake

Não vamos criar um terceiro nível conceitual só para a interface. A navegação deve nascer da estrutura real do banco.

### 4. Crescimento seguro

A arquitetura visual precisa continuar elegante mesmo quando a comunidade adicionar dezenas de passos em certas famílias.

### 5. Colaboração continua visível

`Sugerir passo` não pode desaparecer. A colaboração é parte central do produto e deve continuar presente na experiência.

## Data and Structure Constraints

### Real hierarchy only

A nova `Collection` deve usar os níveis reais já existentes no banco:

- seções
- subseções
- passos

Se a estrutura atual não estiver boa para a nova navegação, o ajuste deve acontecer no banco real por migration, não por uma camada visual paralela.

### Production-aligned taxonomy review

Antes de implementar a reorganização final da taxonomia:

- usar o backup JSON de produção como fonte rápida de leitura
- restaurar esse backup localmente antes de rodar migrations estruturais
- validar localmente em cima de um banco equivalente ao de produção

## Product Direction

## Recommended approach: Drill-down in an editorial grid

Esta é a abordagem recomendada para a `Collection`.

Ela combina:

- linguagem editorial mais quente
- grandes quadrados/cards clicáveis
- drill-down progressivo
- estabilidade para crescimento
- boa adaptação para app e desktop

## Navigation Model

### Level 0: Overview

A primeira dobra mostra:

- hero mais curto
- busca visível, mas secundária ao visual
- filtros recolhíveis
- grid de grandes cards das macro seções reais
- card de `Sugerir passo` com cor própria

### Level 1: Entering a macro section

Ao clicar em uma macro seção:

- a própria tela se reorganiza
- não vai para uma nova rota imediatamente
- a seção escolhida ganha protagonismo
- surgem subseções reais daquela família
- surgem até 3 passos destacados

Esse primeiro aprofundamento deve acontecer na mesma tela, com uma transição elegante e clara.

### Level 2: Going deeper

Se a pessoa quiser aprofundar mais:

- pode seguir navegando pela família
- ou abrir um preview rápido do passo
- ou entrar na página completa do passo quando quiser mais detalhe

## First Fold

### Hero

O hero da `Collection` deve ficar mais curto e mais funcional do que o atual:

- título forte
- subtítulo curto
- menos “texto de manifesto”
- mais foco em descoberta

Exemplo de papel do hero:

- contextualizar o acervo
- dar tom editorial
- não competir com os cards

### Search

A busca continua importante, mas deixa de ser o centro absoluto da página.

Ela deve:

- permanecer fácil de localizar
- ter boa presença visual
- funcionar como ferramenta de atalho, não como única forma de entrar no acervo

### Filters

Os filtros deixam de ficar todos escancarados no topo.

Direção:

- ficar em um controle recolhível
- com linguagem de ajustes/tune, não lupa
- especialmente importante para limpar o mobile

## Macro Section Cards

Os cards do primeiro nível devem ser grandes, elegantes e claramente clicáveis.

Cada card principal deve ter:

- imagem quadrada ou quase quadrada
- título forte
- micro-resumo curto
- indicação sutil de volume ou popularidade
- leitura clara de que aquele bloco aprofunda a navegação

### Placeholder image strategy

Nesta primeira implementação:

- o layout já deve nascer pronto para imagem
- podem ser usados placeholders temporários
- depois as imagens reais serão trocadas uma a uma

O formato esperado é quadrado, para facilitar consistência no app e no desktop.

## Second-Level Content

Ao entrar numa macro seção, o conteúdo deve combinar:

- subseções reais
- até 3 passos destacados

### Featured steps

Os passos destacados:

- são ordenados por popularidade
- usam likes como sinal principal
- ajudam a pessoa a descobrir rapidamente o que é mais relevante naquela família

### Popularity for sections

Não haverá like próprio de seção.

A popularidade visual da seção será derivada dos passos dentro dela, por exemplo a partir de:

- soma ou agregação de likes dos passos
- presença de passos muito curtidos
- densidade/relevância visual da família

Isso evita complexidade extra no banco.

## Step Preview

Ao clicar em um passo destacado, a pessoa não deve ser arrancada da exploração imediatamente.

Direção:

- abrir um preview rápido
- reaproveitar a boa linguagem dos drawers atuais
- mostrar resumo, contexto e ações essenciais

Esse preview deve funcionar como uma camada leve entre:

- exploração do acervo
- leitura detalhada do passo

## Suggest Step

`Sugerir passo` continua sendo um elemento importante da tela.

### Presentation

Em vez de ser só um botão perdido no topo:

- ele entra como um card visual próprio
- com cor diferente
- integrado à malha da `Collection`

### Context-aware form

Quando a pessoa aciona o fluxo já dentro de uma macro seção:

- a seção atual vem pré-selecionada
- mas continua editável

Isso reduz fricção sem prender a pessoa a um único contexto.

## Visual Direction

### Tone

A direção visual recomendada é:

- editorial quente
- cultural
- viva
- elegante

Não é:

- e-commerce
- catálogo frio
- dashboard seco

### Visual traits

- mais respiro
- cards com papéis visuais diferentes
- imagem fazendo parte da navegação
- títulos fortes
- descrições curtas
- sinais de popularidade discretos, mas presentes

### Web

No navegador:

- usar melhor a largura disponível
- evitar coluna estreita no centro
- distribuir a malha de cards com mais presença horizontal

### Mobile

No app:

- cards empilhados ou grade 2-colunas quando fizer sentido
- toque fácil
- leitura clara
- sem excesso de controles na primeira dobra

## Interaction Model

### First click behavior

Primeiro clique:

- reorganiza a própria tela
- mantém contexto
- reforça sensação de exploração

### Deeper navigation

Segundo momento:

- preview de passo
- aprofundamento adicional quando necessário
- navegação para página completa só quando fizer sentido

### Transition feel

As transições devem sugerir:

- continuidade
- reorganização natural
- não reload duro

## Scalability Rules

Esta tela precisa continuar boa quando a comunidade crescer.

Se uma família ganhar dezenas de novos passos:

- o nível macro continua estável
- o segundo nível se adapta
- destaques por likes ajudam na priorização
- a interface não vira listona novamente

## Implementation Implications

### Likely no new data layer for UI

A primeira versão da nova `Collection` deve evitar criar uma camada paralela de organização só para a UI.

### Taxonomy cleanup may require migrations

Seções e subseções atuais podem precisar:

- renomeação
- fusão
- reagrupamento

Essas mudanças devem acontecer por migration, nunca só em memória ou em mapeamento improvisado.

### Backup-based validation

Fluxo recomendado antes de migrations estruturais:

1. usar o backup JSON para mapear a taxonomia real
2. restaurar o backup localmente
3. rodar migrations no banco local restaurado
4. validar que a nova navegação continua coerente

## Validation

### Manual validation

Validar:

- primeira dobra no desktop
- primeira dobra no app
- drill-down dentro de uma macro seção
- preview de passo
- card de sugerir passo com pré-seleção contextual
- busca e filtros sem poluir a experiência

### Automated validation

Cobertura automatizada deve focar em:

- renderização dos blocos estruturais
- comportamento de drill-down
- pré-seleção contextual da sugestão
- estabilidade dos fluxos já existentes de busca e sugestão

## Out of Scope for This Design Pass

- definir ainda todas as imagens finais
- criar sistema novo de likes para seções
- reinventar o drawer inteiro
- adicionar um terceiro nível conceitual fake para organização visual
- mexer em analytics ou recomendações complexas

## Recommended Next Step

O próximo passo deve ser escrever um plano de implementação em duas frentes coordenadas:

1. **mapear a taxonomia real com o backup e decidir o que precisa de migration**
2. **implementar a nova `Collection` com grid editorial e drill-down progressivo**
