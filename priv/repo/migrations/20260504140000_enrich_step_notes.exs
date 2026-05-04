defmodule OGrupoDeEstudos.Repo.Migrations.EnrichStepNotes do
  use Ecto.Migration

  @moduledoc """
  Migration 1/3 do enriquecimento de dados.

  Atualiza o campo `note` de 80 passos com descrições didáticas
  combinando as notas manuais do Tavano (mecânica precisa) com
  a reescrita do GPT (fluência e contexto).

  Tom: narrativo/didático para aluno intermediário.
  Sem entradas/saídas (o grafo cuida disso).
  2-4 frases por passo, focando em COMO executar.

  Fonte: ~/Downloads/passos_forro.json + backup de produção 2026-05-04
  Reversibilidade: down/0 é no-op. Rollback via restore_backup.
  """

  def up do
    # ══════════════════════════════════════════════════════════════════════════
    # BASES (6 passos)
    # ══════════════════════════════════════════════════════════════════════════

    # BF - Base frontal
    update_note("BF", """
    A base frontal é o ponto de partida de toda a dança roots. O casal troca \
    peso de um pé pro outro com passadas curtas, mantendo o abraço estável e o \
    centro de massa sempre sobre o pé de apoio. A passada deve ser pequena, \
    especialmente em músicas rápidas, para que os dois se sintam confortáveis \
    e o abraço não se desfaça.\
    """)

    # BFR - Base frontal romântica
    update_note("BFR", """
    Variação da base frontal com uma qualidade mais suave e íntima. A ginga \
    é macia e o movimento lateral é leve, como se o casal estivesse \
    se balançando junto. A troca de peso permanece clara mas o clima é mais \
    romântico, sem perder a estrutura da base.\
    """)

    # BA - Balanço
    update_note("BA", """
    Balanço lateral curto a partir da base frontal. O condutor desloca o centro \
    de massa para o lado, criando um momento de suspensão, uma pequena pausa \
    antes de decidir o próximo caminho. Esse instante gera a intenção para \
    sacada de esquerda e também para arrastes.\
    """)

    # BE - Base estranha
    update_note("BE", """
    Nessa variação, o pé direito do condutor vai à frente em vez de voltar \
    atrás ao retornar ao meio, invadindo o espaço da conduzida e mudando \
    toda a leitura da base. Essa mudança sutil é o que habilita a entrada \
    no Giro Paulista Estranho (GPE): a condução vem do tronco, com intensidade \
    crescente quando a perna esquerda avança, e a conduzida literalmente não \
    tem outra opção mecânica senão o GPE.\
    """)

    # DA-R - Dança aberta roots
    update_note("DA-R", """
    Na dança aberta roots, o condutor avança o pé esquerdo à frente em vez de \
    recuar, criando uma base própria e mais frontal. Quando o condutor abre para \
    trás no lugar de avançar o pé direito, gera intenção lateral, podendo entrar \
    em sacada armada, onde a condução vem pelos braços e não pela coxa como na \
    sacada padrão. A partir dessa posição se abrem caminhadas abertas, travas \
    abertas e sacadas sem peso.\
    """)

    # DA-U-RE - Repique universitário
    update_note("DA-U-RE", """
    Abertura com as duas mãos em base aberta, criando um espaço claro entre os \
    corpos. Essa posição deixa o quadril da conduzida livre para a sacada de \
    quadril, que aqui é conduzida mais pelos braços do que pela proximidade \
    dos corpos.\
    """)

    # ══════════════════════════════════════════════════════════════════════════
    # CAMINHADAS (7 passos)
    # ══════════════════════════════════════════════════════════════════════════

    # CA-I - Caminhada Itaúnas
    update_note("CA-I", """
    Caminhada em linha reta onde o condutor recua e a conduzida avança. Em \
    músicas rápidas, a passada deve ser ainda mais curta para manter o conforto \
    e não perder o abraço. O centro de massa guia o deslocamento, os pés \
    acompanham, não puxam.\
    """)

    # CA-E - Caminhada esquerda
    update_note("CA-E", """
    Caminhada para a esquerda do casal, puxada pelo centro de massa. O \
    deslocamento é curto e contínuo, sem abrir demais o abraço. A condução \
    vem da transferência de peso lateral, e o casal se desloca como um \
    bloco. Se o abraço estica, a passada está grande demais.\
    """)

    # CA-E-DA - Caminhada esquerda na dança aberta
    update_note("CA-E-DA", """
    A mesma lógica da caminhada esquerda, mas em posição aberta. Com \
    mais espaço entre os corpos, a leitura fica mais visual: a conduzida \
    consegue ver melhor o que está acontecendo e o condutor precisa ser mais \
    claro na intenção. Executada a partir da dança aberta roots.\
    """)

    # CA-F - Caminhada frontal
    update_note("CA-F", """
    Caminhada em diagonal, levemente a quarenta e cinco graus para a esquerda. \
    Esse ângulo deixa a condução mais leve e confortável do que caminhar em \
    linha reta. É uma das caminhadas mais versáteis, e daqui se sai tanto \
    para pião quanto para pião invertido.\
    """)

    # CA-BF - Caminhada/batida frontal
    update_note("CA-BF", """
    Caminhada com uma batida leve do pé atrás em tempo duplo, sem quebrar o \
    fluxo do deslocamento. A batida funciona como um acento musical dentro \
    da caminhada: não é um passo extra, é uma marcação que dá textura \
    rítmica ao movimento.\
    """)

    # CA-CT - Caminhada com contorno
    update_note("CA-CT", """
    O condutor fica parado no lugar enquanto a conduzida contorna o corpo dele, \
    pisando atrás com a esquerda. O desenho é mais circular do que as outras \
    caminhadas. Na volta, a intenção de sacada já está pronta, e daqui se \
    entra facilmente em sacada, giro paulista ou trava.\
    """)

    # CA-TZ - Caminhada cruzada com trava final
    update_note("CA-TZ", """
    A caminhada começa com o pé direito cruzando por trás do esquerdo, já \
    fechando o corpo num desenho que naturalmente leva a uma trava. O cruzamento \
    inicial é o que diferencia essa caminhada: muda a mecânica de saída e \
    prepara o corpo para finalizar travado.\
    """)

    # ══════════════════════════════════════════════════════════════════════════
    # SACADAS (12 passos)
    # ══════════════════════════════════════════════════════════════════════════

    # SC - Sacada simples
    update_note("SC", """
    A sacada nasce da transferência de peso: o condutor desloca o centro de \
    massa, liberando a perna da conduzida por baixo enquanto a coxa participa \
    do desenho. O pé dela sai por baixo da coxa dele. Não é um chute, é \
    uma consequência da transferência de peso. É um dos movimentos centrais \
    do vocabulário roots.\
    """)

    # SC-E - Sacada de esquerda
    update_note("SC-E", """
    A sacada de esquerda tem mecânica própria e não depende da intenção de \
    sacada padrão (que prepara a sacada direita). Aqui a transferência de peso \
    entra direto pela mecânica do movimento, sem aquela preparação clássica \
    que antecede a sacada convencional.\
    """)

    # SCSP - Sacada sem peso
    update_note("SCSP", """
    Na sacada sem peso, o condutor não assume o peso inteiro sobre a perna \
    que entra. A sacada acontece mas o corpo não se compromete totalmente. \
    A finalização fecha num chassê curto e leve, o que permite seguir para \
    vários caminhos diferentes.\
    """)

    # SCSP-BE - Com pézin esquerdo batendo 1
    update_note("SCSP-BE", """
    A sacada sem peso termina sem transferir todo o peso e já emenda direto \
    num balanço para a esquerda, usando o footwork da base 1. A transição \
    entre a sacada e o balanço deve ser fluida. Se houver pausa, perdeu \
    a intenção.\
    """)

    # SCSP-DA - Sacada sem peso na dança aberta
    update_note("SCSP-DA", """
    A mesma sacada sem peso, mas executada em posição aberta. Com mais espaço \
    entre os corpos, a leitura é mais visual e o retorno vai para a dança \
    aberta roots. A condução aqui depende mais dos braços do que da \
    proximidade do quadril.\
    """)

    # SCSP-PDI-ET-BE - Falso balanço esquerdo
    update_note("SCSP-PDI-ET-BE", """
    Finalização elaborada da sacada sem peso: o pé direito fecha para dentro, \
    o pé esquerdo passa por trás do direito, e só então entra o balanço para \
    a esquerda. São três ações encadeadas (pé direito fecha, esquerda cruza \
    por trás, balanço) que exigem precisão de timing para não embolar.\
    """)

    # SCSP-TP - Com troca rápida
    update_note("SCSP-TP", """
    Antes do balanço para a esquerda, acontece uma troca rápida de peso pela \
    direita. Essa troca a mais dá um impulso que deixa a saída para o balanço \
    mais viva e com mais energia. É sutil mas muda a qualidade do movimento.\
    """)

    # SCxX - Sacada múltipla (sacadas alternadas)
    update_note("SCxX", """
    Sacadas alternadas em sequência: sacada pra um lado, sacada pro outro. \
    Exige coordenação precisa de tempo entre condutor e conduzida, porque a \
    leitura muda de direção rapidamente. Se um dos dois atrasar, o movimento \
    perde a fluidez.\
    """)

    # PP - Pica-pau
    update_note("PP", """
    Logo depois da sacada, o pé marca batidas rápidas no chão, como um pica-pau \
    bicando. É um floreio rítmico que aproveita o momento em que a perna está \
    livre após a sacada. As batidas são leves e rápidas, mais percussivas do \
    que pesadas.\
    """)

    # SIR - Siri
    update_note("SIR", """
    Saindo da sacada de esquerda, os pés andam miudinhos pro lado, como se \
    estivessem desenhando um siri no chão. O deslocamento lateral é pequeno \
    e os passos são curtos. Se a passada for grande, perde o efeito.\
    """)

    # ══════════════════════════════════════════════════════════════════════════
    # GIROS (5 passos)
    # ══════════════════════════════════════════════════════════════════════════

    # GP - Giro paulista
    update_note("GP", """
    Giro invertido em posição aberta, com rotação contínua e troca de lado \
    bem organizada pelo centro do corpo. É um dos passos mais versáteis do \
    vocabulário e funciona tanto como saída de sacada quanto como ponte \
    para caminhadas, piões e footwork. A qualidade do giro depende do eixo: \
    se o centro de massa sai do lugar, o giro desmorona.\
    """)

    # GP-D - Giro paulista duplo
    update_note("GP-D", """
    A conduzida faz uma volta e meia enquanto o condutor encaixa seus próprios \
    passos (cinco passos em contratempo ou três em tempo) antes de fechar \
    o abraço novamente. A conduzida precisa manter o eixo por mais tempo do \
    que no paulista simples, porque a rotação é mais longa.\
    """)

    # GPC - Giro paulista de costas
    update_note("GPC", """
    Paulista executado com os parceiros de costas um para o outro. Exige mais \
    intensidade na condução. Pode ser feito com qualquer mão (esquerda, \
    direita, ou com as duas mãos simultaneamente). No caso das duas mãos, \
    elas geram intensidade para o centro e soltam como um X, criando a \
    rotação. É mais desafiador porque a leitura corporal é toda pelo tato, \
    sem referência visual.\
    """)

    # GCH - Giro chicote
    update_note("GCH", """
    Giro com efeito de chicote: o condutor acumula a rotação segurando o \
    movimento e solta essa energia de uma vez, gerando um retorno elástico. \
    A sensação é de comprimir uma mola e liberar. A conduzida sente o \
    impulso e responde com a rotação.\
    """)

    # PI - Pião horário (padrão)
    update_note("PI", """
    O pião é um giro conjunto onde os dois giram como um bloco, mantendo o \
    abraço fechado e a rotação compacta. O segredo é não perder o próprio \
    eixo durante a rotação: o centro de massa de cada um deve ficar sobre \
    seu próprio pé de apoio, não sobre o parceiro. Quando o giro termina em \
    número ímpar de meios-giros, abre direto para o giro paulista.\
    """)

    # PI-INV - Pião anti-horário (invertido)
    update_note("PI-INV", """
    Versão invertida do pião, girando no sentido anti-horário. O lado do \
    abraço muda durante a rotação, o que pede um eixo bem organizado porque \
    a troca de referência no meio do giro é desorientadora. Um combo elegante \
    é alternar pião invertido com caminhada frontal: PI-INV, CA-F, PI-INV, CA-F.\
    """)

    # ══════════════════════════════════════════════════════════════════════════
    # INVERSÃO (2 passos)
    # ══════════════════════════════════════════════════════════════════════════

    # IV - Inversão base
    update_note("IV", """
    Meia virada invertida em linha, usada para trocar a direção do casal sem \
    abrir demais o abraço. É um passo de transição muito útil: a partir da \
    inversão se abrem sacadas, caminhadas, travas, giros e praticamente \
    qualquer saída via intenção de sacada.\
    """)

    # IV-CT - Finta pós-inversão
    update_note("IV-CT", """
    Simula uma entrada em caminhada após a inversão, mas em vez de seguir em \
    frente, a conduzida pisa atrás e volta. O condutor puxa de volta num \
    desenho mais circular. A condução é mais redonda do que na inversão padrão. \
    Daqui se sai bem para sacada, paulista ou trava.\
    """)

    # ══════════════════════════════════════════════════════════════════════════
    # TRAVAS (3 passos)
    # ══════════════════════════════════════════════════════════════════════════

    # TR-ARM - Trava armada
    update_note("TR-ARM", """
    Os dois jogam o centro de massa para a direita, criando um elástico. Na \
    virada, o condutor cruza a direita pela frente enquanto a conduzida cruza \
    a esquerda, os dois cruzam em sentidos opostos até travar. As barrigas \
    ficam de frente com um leve V durante o elástico; esse V gira, e no meio \
    os dois cruzam as pernas pela frente. Marca forte nesse lado, depois o \
    condutor volta para trás como nas voltas do roots.\
    """)

    # TR-DA - Trava na dança aberta
    update_note("TR-DA", """
    Versão aberta da trava, com mais espaço entre os corpos. O cruzamento \
    acontece sem fechar tanto o abraço, então a condução precisa ser mais \
    clara nos braços para compensar a distância. Executada a partir da dança \
    aberta roots, e retorna para ela.\
    """)

    # TRD - Trocadilho
    update_note("TRD", """
    Saída depois da intenção de sacada. O condutor cruza a perna direita por \
    trás enquanto a conduzida cruza a direita pela frente, os dois cruzam \
    em sentidos opostos e fecham o corpo num desenho curto. É uma das saídas \
    mais comuns depois da sacada e das caminhadas.\
    """)

    # ══════════════════════════════════════════════════════════════════════════
    # ABERTURAS E OUTROS (3 passos)
    # ══════════════════════════════════════════════════════════════════════════

    # AB-C - Abraço lateral
    update_note("AB-C", """
    Abertura que cria espaço lateral entre o casal a partir do abraço. A mão \
    do condutor pode apoiar na cintura ou no ombro da conduzida. Se subir \
    muito, vira chuveirinho, que é outro passo. Pode ser feita com ou sem \
    troca de lado.\
    """)

    # ALC - Bêbado
    update_note("ALC", """
    O condutor joga o centro de massa para a direita, abrindo a base com o \
    pé direito para o lado. A perna esquerda segue rápida por trás da \
    direita, e depois a direita ajusta, voltando o corpo para trás do \
    condutor. O movimento todo lembra alguém cambaleando, daí o nome: \
    abertura lateral, cruzada rápida por trás e ajuste.\
    """)

    # AR-D - Armar pra direita
    update_note("AR-D", """
    O condutor leva o centro de massa dos dois com decisão para a direita, \
    criando um deslocamento forte e claro. Esse arraste funciona como \
    preparação para passos que seguem para o lado esquerdo. Caminhadas \
    e travas entram naturalmente depois dessa armação.\
    """)

    # ══════════════════════════════════════════════════════════════════════════
    # PESCADA (1 passo)
    # ══════════════════════════════════════════════════════════════════════════

    # PE-E-E - Pescada esquerda-esquerda
    update_note("PE-E-E", """
    No fim da caminhada, a perna esquerda do condutor encaixa com a perna \
    esquerda da conduzida, prendendo o movimento na pescada. O condutor \
    fica de costas nessa posição. É uma finalização limpa que abre para \
    pião ou para voltar à base.\
    """)

    # ══════════════════════════════════════════════════════════════════════════
    # FOOTWORK - HF-* (42 passos)
    # Passos catalogados a partir do canal @forro_footwork.
    # ══════════════════════════════════════════════════════════════════════════

    # HF-A5T - Avião into 5 Step Turn
    update_note("HF-A5T", """
    Avião seguido de um giro de cinco passos, juntando troca de braço e \
    rotação numa mesma frase. É enganosamente complicado: parece simples \
    de longe, mas a transição entre o avião e o giro exige timing preciso \
    na mudança de mão.\
    """)

    # HF-AFI - Active Follower Intercept
    update_note("HF-AFI", """
    A conduzida percebe a proposta do condutor e responde com uma interrupção \
    ativa. Em vez de seguir a sugestão, ela muda o rumo do movimento por \
    conta própria, sem perder a conexão. É um exercício de following ativo: \
    a conduzida não é passiva, ela propõe.\
    """)

    # HF-ALC - Facão Leg Catch
    update_note("HF-ALC", """
    Dentro de uma inversão (facão), o condutor captura a perna da conduzida \
    como floreio decorativo e devolve o movimento sem quebrar o fluxo. A \
    captura é rápida e controlada. Não é uma trava, é um toque que \
    acrescenta textura sem interromper o passo.\
    """)

    # HF-AVB - Avião com Bloqueio
    update_note("HF-AVB", """
    Finalização alternativa do avião que termina num bloqueio claro, segurando \
    o fluxo antes da próxima escolha. Em vez de deixar o avião fluir e sair, \
    o condutor freia o movimento com um bloqueio e decide o próximo passo a \
    partir dali.\
    """)

    # HF-AWK - Armwork for Followers and Leaders
    update_note("HF-AWK", """
    Mais do que um passo específico, é um estudo de braços: trabalho de \
    conexão de mãos e desenho de braços tanto para condutor quanto para \
    conduzida. Baseado em masterclass. O foco está na qualidade do toque \
    e na fluidez dos movimentos de braço, não nos pés.\
    """)

    # HF-B2TA - Base 2 Turn Away
    update_note("HF-B2TA", """
    Saída pós-caminhada: o condutor avança o pé direito e gira trezentos e \
    sessenta graus em sentido anti-horário em três tempos. A conduzida reverte \
    naturalmente para a base 2. O giro do condutor precisa ser compacto, porque \
    se abrir demais, perde o abraço.\
    """)

    # HF-CAB - Caminhada Block
    update_note("HF-CAB", """
    Caminhada que avança e bloqueia o fluxo no momento certo, criando um \
    freio claro antes da continuação. É difícil de dominar porque o timing \
    do bloqueio precisa ser preciso: cedo demais e o movimento não tem \
    impulso, tarde demais e a conduzida já passou.\
    """)

    # HF-CAI - Itaúnas Invertido
    update_note("HF-CAI", """
    O condutor muda a acentuação para os tempos um, três, cinco e sete, \
    seguindo um padrão de paradiddle. Enquanto isso, a conduzida mantém a \
    base dois normal. O ciclo completo tem dezesseis tempos. É um exercício \
    de dissociação: cada um dança num ritmo diferente mas juntos.\
    """)

    # HF-CCS - Cha Cha Sacada
    update_note("HF-CCS", """
    Versão estendida da sacada com arrastada: encadeia sacada para a esquerda, \
    depois para a direita, e de volta, num ritmo que lembra o cha-cha. A \
    perna livre fica sempre pronta para o próximo desenho. Se o pé pousar \
    pesado entre as sacadas, o encadeamento trava.\
    """)

    # HF-CPH - Continuation Spin Hand Drop
    update_note("HF-CPH", """
    Variação do R2L (Right to Left): depois da continuação do giro, a mão da \
    conduzida cai naturalmente e o movimento segue mais solto, sem a tensão \
    da conexão de mãos. A queda da mão não é um erro. É intencional e muda \
    a qualidade do que vem depois.\
    """)

    # HF-CWB - Cowboy Sequence
    update_note("HF-CWB", """
    Sequência que combina chicote (GCH), saída espanhola e um laço, costurando \
    tudo num fluxo contínuo de braços e giro. Cada elemento emenda no seguinte. \
    Se pausar entre eles, a sequência perde a identidade. O chicote é o \
    mesmo já catalogado como GCH.\
    """)

    # HF-DD - Double Duckerfly
    update_note("HF-DD", """
    Passo raro e chamativo que mistura abaixada do tronco com abertura de braços \
    e passagem compacta (um duck combinado com butterfly). Exige bastante cuidado \
    com o espaço porque há risco de cotovelos no rosto. Praticar devagar e com \
    consciência do espaço ao redor.\
    """)

    # HF-DHS - Double Hand Spin
    update_note("HF-DHS", """
    A conduzida gira com as duas mãos ainda conectadas ao condutor. No final \
    do giro, os braços despencam naturalmente para os lados. A sustentação \
    das duas mãos durante o giro dá mais controle, mas exige que ambos \
    mantenham os braços relaxados para não travar a rotação.\
    """)

    # HF-EN - Vem Neném
    update_note("HF-EN", """
    Sequência com troca de peso em seis dos sete passos. A troca no tempo \
    morto é contra-intuitiva mas recompensadora. É boa para brincar com \
    contratempo e musicalidade. O nome não é coincidência: tem uma qualidade \
    provocativa e brincalhona quando bem executada.\
    """)

    # HF-FCS - Foot Catch Spin
    update_note("HF-FCS", """
    O giro já emenda direto na captura do pé, deixando a pescada aparecer \
    de um jeito fluido e contínuo, sem interrupção entre o giro e a \
    captura. A transição precisa ser limpa: se o condutor pausar para \
    pescar, perde a fluidez.\
    """)

    # HF-FSC - Follower Sacada
    update_note("HF-FSC", """
    Aqui quem executa a sacada é a conduzida, não o condutor. Ela toma a \
    iniciativa e devolve a proposta com participação ativa. É um exercício \
    de following ativo: a conduzida não espera a condução, ela propõe \
    o movimento.\
    """)

    # HF-HHS - Hand to Hand Slide
    update_note("HF-HHS", """
    A conexão escorrega da mão direita alta do condutor, descendo pelo braço, \
    até encontrar a mão esquerda da conduzida. O deslize precisa ser contínuo \
    e sem interrupção. Se a mão pular de um ponto a outro, perde a qualidade \
    do toque. É um floreio de braço que exige sensibilidade.\
    """)

    # HF-HRB - High Right Block Spin
    update_note("HF-HRB", """
    Depois de um bloqueio com a mão direita em posição alta, o condutor desce \
    a mão pelo braço da conduzida, e esse deslize acende um novo giro. A \
    transição entre o bloqueio e o giro é onde mora a dificuldade: se a mão \
    descer rápido demais, o giro sai descontrolado.\
    """)

    # HF-IP1 - Interrupted Paulista 1
    update_note("HF-IP1", """
    Paulista interrompido: o condutor não solta a mão no meio do giro, \
    posicionando os dois lado a lado. A mão esquerda baixa e trava a \
    rotação embaixo. É uma pausa intencional dentro do giro, onde os dois \
    ficam lado a lado num instante de suspensão antes de decidir a \
    continuação.\
    """)

    # HF-LF - Leader Faint
    update_note("HF-LF", """
    A entrada parece um giro simples, mas no meio do movimento o condutor \
    desliza a mão direita pelas costas da conduzida até reaparecer do outro \
    lado. É um floreio do condutor (uma finta): a conduzida sente a mão \
    viajando pelas costas e precisa manter o eixo enquanto isso acontece.\
    """)

    # HF-MV7 - Manivela Variation 7 Steps
    update_note("HF-MV7", """
    Variação da manivela em sete passos, para quem o giro de cinco já ficou \
    simples e quer uma frase mais longa. A sensação de giro é mais esticada, \
    a rotação dura mais tempo e exige mais controle de eixo. Os dois \
    passos extras mudam o ponto de resolução do giro.\
    """)

    # HF-NS - Pêndulo Sacada
    update_note("HF-NS", """
    Deslize lateral combinado com pêndulo, em cinco passos. Pode ser feito \
    com ou sem pausa entre as repetições. O deslize prepara uma sequência de \
    sacadas repetidas no ritmo 1-3, 1-3. A neutralidade do slide é o que \
    permite encadear as sacadas sem reorganizar o corpo.\
    """)

    # HF-PBV - Paulista Variation Bate e Volta
    update_note("HF-PBV", """
    Variação do paulista em que a rotação vai e volta, um efeito curto de \
    rebate no próprio giro, como uma bola batendo na parede. O condutor \
    inverte a direção no meio da rotação, o que exige clareza na condução \
    para que a conduzida não continue girando na primeira direção.\
    """)

    # HF-PLS - Pêndulo Lateral + Sacada + Caminhada com Pausa
    update_note("HF-PLS", """
    Uma das combinações mais estilosas: pêndulo lateral encadeado com sacada \
    e caminhada com pausa, tudo num fluxo só. A mistura funciona porque cada \
    elemento prepara o seguinte. O pêndulo gera a intenção da sacada, que \
    abre a caminhada, que pausa no momento certo.\
    """)

    # HF-PRC - Paulista Release Come Back Twist
    update_note("HF-PRC", """
    A preparação é igual ao paulista, mas o condutor solta a conexão depois \
    do bloqueio. A energia acumulada no bloqueio empurra a conduzida para \
    um giro de cinco passos. O momento de soltar é crucial: cedo demais e \
    não tem energia, tarde demais e trava.\
    """)

    # HF-PS - Pequeno Salto
    update_note("HF-PS", """
    O condutor marca um pequeno salto enquanto a conduzida continua lendo um \
    giro fluido e contínuo. É uma variação de musicalidade onde o salto do \
    condutor é um acento que não interfere na rotação dela. Se o salto \
    for grande demais, desestabiliza o abraço.\
    """)

    # HF-PT - Push Turn
    update_note("HF-PT", """
    Giro de empurrão com mudança de direção: o condutor empurra gentilmente \
    e bloqueia no tempo dois, a conduzida pivota no pé esquerdo no tempo \
    quatro e retorna. A mudança de direção no meio é o que diferencia \
    esse giro. Não é uma rotação contínua, é um vai-e-vem.\
    """)

    # HF-R2L - Right to Left Spin Continuation
    update_note("HF-R2L", """
    Saída pós-giro pela mão direita: o condutor pega a mão esquerda da \
    conduzida com a mão direita e continua a rotação em sentido horário. \
    A troca de mão no meio do giro precisa ser suave. Se apertar, trava; \
    se largar, perde a conexão.\
    """)

    # HF-R2R - Right to Right Block Block Block
    update_note("HF-R2R", """
    Conexão mão direita do condutor com mão direita da conduzida, seguida \
    de três bloqueios consecutivos. Cada bloqueio é bem marcado: são três \
    paradas dentro de um mesmo fluxo, o que dá um caráter percussivo ao \
    movimento.\
    """)

    # HF-RS - Reverse Sacada
    update_note("HF-RS", """
    A sacada reversa nasce no caminho contrário ao esperado. Em vez de sacar \
    na direção habitual, o movimento vem pelo lado oposto. Funciona bem como \
    extensão ou finalização alternativa da caminhada block (HF-CAB). É uma \
    variação que surpreende pela inversão da expectativa.\
    """)

    # HF-S3 - Side to Side to Side
    update_note("HF-S3", """
    Logo depois de um giro, o condutor abaixa as mãos como sinal e inicia \
    um deslocamento lateral em sequência: lado, lado, lado. O abaixamento \
    das mãos funciona como aviso claro para a conduzida de que o próximo \
    movimento é lateral, não rotacional.\
    """)

    # HF-SCA - Sacada com Arrastada
    update_note("HF-SCA", """
    No passo recuado, o condutor cruza as pernas e usa a coxa esquerda para \
    executar a sacada, seguida de um arraste do pé. O cruzamento das pernas \
    no recuo é o que gera a mecânica: sem ele, a sacada não tem a angulação \
    certa. O arraste no final é o que dá identidade ao passo.\
    """)

    # HF-SLC - Sacada Leg Catch
    update_note("HF-SLC", """
    A sacada combina com uma captura de perna no meio do desenho. Exige \
    bastante precisão para não bater canela, porque o espaço entre as pernas \
    é pequeno. Recomendável praticar primeiro sem sapatos até ter o controle \
    fino da distância.\
    """)

    # HF-SPB - The Spin Block
    update_note("HF-SPB", """
    O bloqueio entra no meio da rotação e reorganiza o corpo da conduzida \
    antes da saída. É considerado um passo essencial no vocabulário de \
    footwork. Combina bloqueio e giro de forma orgânica, sem que um \
    interrompa o outro.\
    """)

    # HF-SRS - Suspended Rotating Sacada
    update_note("HF-SRS", """
    Sacada rotativa suspensa: a perna sacada fica suspensa no ar por mais \
    tempo do que o habitual, até o tempo cinco do próximo compasso. O corpo \
    gira enquanto a perna está no ar, com uma leve pausa durante a rotação. \
    Exige bom equilíbrio de ambos.\
    """)

    # HF-STD - Sacada de Trava Deco
    update_note("HF-STD", """
    O condutor cruza o pé direito por trás e libera espaço para uma varredura \
    com o pé esquerdo. A conduzida aproveita com a perna direita: enquanto \
    ele varre, ela acompanha o desenho. O cruzamento do condutor é a chave, \
    pois sem ele não sobra espaço para a varredura.\
    """)

    # HF-STS - Side to Slide
    update_note("HF-STS", """
    Deslize lateral alternado: o condutor desliza a direita, cruza a esquerda \
    por trás transferindo o peso, e libera o pé direito da conduzida para \
    deslizar na direção oposta. Os dois deslizam de um lado ao outro com \
    troca de peso cruzada. É um diálogo lateral de pés.\
    """)

    # HF-TAS - Turn Away Spin Overhead
    update_note("HF-TAS", """
    Logo após um giro, o condutor gira no próprio lugar e bloqueia com a mão \
    direita por cima. A conduzida gira por baixo do braço dele. O timing \
    entre o giro do condutor e a passagem dela por baixo precisa ser preciso: \
    se ele atrasar o bloqueio, ela já passou.\
    """)

    # HF-TAV - Turning Avião
    update_note("HF-TAV", """
    Um avião que continua girando, combinando troca de braço, deslocamento e \
    rotação sem parar. Tem muita coisa acontecendo ao mesmo tempo (braço \
    troca, corpo gira, posição muda). É um passo que exige prática separada \
    de cada componente antes de juntar tudo.\
    """)

    # HF-TDC - Trocadilho do Condutor
    update_note("HF-TDC", """
    Dura oito tempos. Nos tempos um, dois e três, o condutor pausa a parte \
    inferior do corpo mas continua guiando com o braço e a abertura do tronco. \
    A conduzida lê essa abertura e pisa para a esquerda. É um exercício de \
    dissociação: parte de cima conduz, parte de baixo espera.\
    """)

    # HF-WO5 - Wax On 5 Step Variant
    update_note("HF-WO5", """
    No giro de cinco passos, o condutor pivota no pé esquerdo e pisa atrás \
    após o primeiro giro. No passo dois de cinco, a mão guia muda para \
    palma direita aberta, o gesto que dá nome ao passo, lembrando o \
    Mr. Miyagi. Essa mudança de mão dá outra textura ao giro.\
    """)

    # HF-YNK - Yoink
    update_note("HF-YNK", """
    O condutor aproveita o momento em que a conduzida está com o peso no pé \
    de trás e puxa esse apoio num roubo rápido de perna. O timing é tudo: \
    se puxar quando ela já transferiu o peso para frente, o roubo não \
    funciona. É surpreendente e divertido quando bem executado.\
    """)
  end

  def down do
    # Rollback manual via restore_backup se necessário.
    # As notas anteriores não foram preservadas no JSON de origem.
    :ok
  end

  # ── Helper ──────────────────────────────────────────────────────────────────

  defp update_note(code, note) do
    clean_note =
      note
      |> String.replace(~r/\\\n\s*/, "")
      |> String.replace(~r/\n\s*/, " ")
      |> String.trim()
      |> String.replace("'", "''")

    execute("""
    UPDATE steps
    SET note = '#{clean_note}', updated_at = NOW()
    WHERE code = '#{code}' AND deleted_at IS NULL
    """)
  end
end
