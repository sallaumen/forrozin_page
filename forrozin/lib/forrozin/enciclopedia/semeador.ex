defmodule Forrozin.Enciclopedia.Semeador do
  @moduledoc """
  Seed inicial da enciclopédia de forró roots.

  Popula categorias, seções, subseções, passos e conceitos técnicos
  a partir dos dados originais do site HTML. Idempotente: chamadas
  subsequentes retornam `:already_seeded` sem modificar o banco.
  """

  alias Forrozin.Enciclopedia.{Categoria, ConceitoTecnico, Passo, Secao, Subsecao}
  alias Forrozin.Repo

  # Códigos HF com imagem em images/
  @hf_cards ~w(
    HF-2345 HF-A5T HF-AFI HF-ALC HF-AVB HF-AWK HF-B2TA HF-CAB HF-CAI HF-CCS
    HF-CPH HF-CWB HF-DD HF-DHS HF-EN HF-FBD HF-FCS HF-FSC HF-FWS HF-HHS
    HF-HRB HF-IP1 HF-LF HF-MV7 HF-NBE HF-NS HF-PBV HF-PLS HF-PRC HF-PS
    HF-PT HF-R2L HF-R2R HF-RS HF-S3 HF-SCA HF-SLC HF-SPB HF-SRS HF-STD
    HF-STS HF-TAS HF-TAV HF-TDC HF-WO5 HF-YNK
  )

  @categorias [
    {"sacadas", "Sacadas", "#c0392b"},
    {"travas", "Travas", "#2980b9"},
    {"caminhadas", "Caminhadas", "#27ae60"},
    {"giros", "Giros", "#8e44ad"},
    {"pescadas", "Pescadas", "#d35400"},
    {"inversao", "Inversão", "#c0392b"},
    {"bases", "Bases", "#16a085"},
    {"outros", "Outros", "#7f8c8d"},
    {"footwork", "Forró Footwork", "#e67e22"},
    {"conceitos", "Conceitos", "#f39c12"},
    {"convencoes", "Convenções", "#95a5a6"}
  ]

  @secoes [
    %{
      titulo: "Convenções da Notação",
      num: nil,
      codigo: nil,
      descricao: nil,
      nota: nil,
      categoria: "convencoes",
      passos: [],
      subsecoes: [
        %{
          titulo: "Direção",
          nota: nil,
          passos: [
            %{codigo: "D", nome: "Direita"},
            %{codigo: "E", nome: "Esquerda"},
            %{codigo: "F", nome: "Frente"},
            %{codigo: "T", nome: "Trás"}
          ]
        },
        %{
          titulo: "Pé Duplo",
          nota: nil,
          passos: [
            %{codigo: "pd(ca-fr)", nome: "Calcanhar → Frente"},
            %{codigo: "pd(fr-ca)", nome: "Frente → Calcanhar"}
          ]
        },
        %{
          titulo: "Saídas de Giros Paulistas",
          nota:
            "Todos os paulistas (GP, GPE, GPC) podem sair aberto ou fechado — sufixos opcionais.",
          passos: [
            %{codigo: "-A", nome: "Saída aberta"},
            %{codigo: "-F", nome: "Saída fechada"},
            %{codigo: "-PC", nome: "Saída pelas costas", wip: true}
          ]
        }
      ]
    },
    %{
      titulo: "Bases",
      num: 1,
      codigo: "B",
      descricao: "Movimentos essenciais, usados como ponto de partida para combinações.",
      nota: nil,
      categoria: "bases",
      passos: [
        %{codigo: "BTR", nome: "Base triangular"},
        %{codigo: "BF", nome: "Base frontal"},
        %{
          codigo: "BFR",
          nome: "Base frontal romântica",
          nota: "Com arraste lateral e ginga suave"
        },
        %{codigo: "BQ", nome: "Base quadrada"},
        %{codigo: "BL", nome: "Base lateral", nota: "Com aberturas e variações"},
        %{
          codigo: "BE",
          nome: "Base estranha",
          nota:
            "Pé direito vai à frente (em vez de trás) ao voltar ao meio — condutor invade o espaço da conduzida. Função: habilitar GPE."
        },
        %{
          codigo: "BA",
          nome: "Balanço",
          nota:
            "Balanço lateral a partir da base frontal. Gera intenção para sacada de esquerda e para arrastes. Momento de suspensão antes da decisão do movimento seguinte."
        }
      ],
      subsecoes: []
    },
    %{
      titulo: "Sacadas",
      num: 2,
      codigo: "SC",
      descricao: "Movimento de interceptação de espaço ou de perna.",
      nota: nil,
      categoria: "sacadas",
      passos: [
        %{
          codigo: "SC",
          nome: "Sacada simples",
          nota:
            "Transferência, pé por baixo, coxa. Entradas: intenção de sacada. Saídas: GP, TRD, PE, CA, PI"
        },
        %{
          codigo: "SC-E",
          nome: "Sacada de esquerda",
          nota: "Mecânica própria — não depende da intenção de sacada padrão. Saídas: PE-E-E, GP"
        },
        %{
          codigo: "SCxX",
          nome: "Sacada múltipla (sacadas alternadas)",
          nota:
            "Sacadas alternadas em sequência — exige coordenação precisa de ambos os parceiros."
        },
        %{
          codigo: "HF-SRS",
          nome: "Suspended Rotating Sacada",
          nota:
            "Sacada rotativa suspensa — perna sacada fica suspensa até o tempo 5 do próximo compasso. Leve pausa durante a rotação.",
          wip: true
        },
        %{
          codigo: "HF-RS",
          nome: "Reverse Sacada",
          nota:
            "Sacada reversa — extensão ou finalização alternativa da Caminhada Block (HF-CAB).",
          wip: true
        },
        %{
          codigo: "HF-NS",
          nome: "Pêndulo Sacada",
          nota:
            "Deslize lateral combinado com Pêndulo. 5 passos sem pausa, ou com pausa. Seguido por sacadas repetidas em 1-3, 1-3.",
          wip: true
        },
        %{
          codigo: "HF-CCS",
          nome: "Cha Cha Sacada",
          nota:
            "Versão estendida da Sacada com Arrastada: sacada esq. → sacada dir. → e de volta.",
          wip: true
        },
        %{
          codigo: "HF-FSC",
          nome: "Follower Sacada",
          nota: "A conduzida executa a sacada — following ativo.",
          wip: true
        },
        %{
          codigo: "HF-SCA",
          nome: "Sacada com Arrastada",
          nota:
            "Condutor cruza as pernas no passo recuado e usa a coxa esquerda para a sacada, seguida de arraste do pé.",
          wip: true
        },
        %{
          codigo: "HF-SLC",
          nome: "Sacada Leg Catch",
          nota:
            "Sacada com captura de perna — arriscado (canela da conduzida). Praticar sem sapatos.",
          wip: true
        },
        %{
          codigo: "HF-STD",
          nome: "Sacada de Trava Deco",
          nota:
            "Condutor cruza pé direito por trás, libera espaço para varredura com o pé esquerdo. Conduzida aproveita com a perna direita.",
          wip: true
        },
        %{
          codigo: "HF-PLS",
          nome: "Pêndulo Lateral + Sacada + Caminhada com Pausa",
          nota: "Das mais estilosas: pêndulo lateral encadeado com sacada e caminhada com pausa.",
          wip: true
        }
      ],
      subsecoes: []
    },
    %{
      titulo: "Sacada sem peso",
      num: 3,
      codigo: "SCSP",
      descricao: nil,
      nota:
        "A condução parte do abdômen e ombro, não do pé. Sempre com 4 tempos de footwork antes da saída em chassê. Antigo nome: CH (Chutinho) — obsoleto.",
      categoria: "sacadas",
      passos: [
        %{codigo: "SCSP", nome: "Sacada sem peso", nota: "Saída em chassê"},
        %{
          codigo: "SCSP-BE",
          nome: "Com pézin esquerdo batendo 1",
          nota: "Seguido de balanço para esquerda (footwork base 1)"
        },
        %{
          codigo: "SCSP-PDI-ET-BE",
          nome: "Falso balanço esquerdo",
          nota: "Finalização de pé direito para dentro, pé esquerdo por trás do direito"
        },
        %{
          codigo: "SCSP-TP",
          nome: "Com troca rápida",
          nota: "Troca rápida pela direita antes do balanço esquerda"
        },
        %{
          codigo: "SCSP-MD",
          nome: "Marca duplo saída mão cruzada",
          nota: "Marca duplo com esquerda pd(ca-fr)-E, entra girando esquerda"
        },
        %{
          codigo: "SCSP-DA",
          nome: "Sacada sem peso na dança aberta",
          nota: "Versão aberta da sacada sem peso. Executada em DA-R, retorna à DA-R."
        }
      ],
      subsecoes: []
    },
    %{
      titulo: "Travas",
      num: 4,
      codigo: "TR",
      descricao: "Travamentos de perna, podem ter sacada ou não.",
      nota:
        "Em trava a perna do condutor vai à frente. O V da abertura entre os parceiros não pode ser muito grande.",
      categoria: "travas",
      passos: [
        %{codigo: "TR-E", nome: "Trava esquerda"},
        %{
          codigo: "TR-FS",
          nome: "Trava frontal sem sacada",
          nota: "Entradas: DA-R, intenção de sacada"
        },
        %{
          codigo: "TR-FC",
          nome: "Trava frontal com sacada",
          nota: "Entradas: DA-R, intenção de sacada"
        },
        %{codigo: "TR-P3", nome: "Trava com pezinho no terceiro tempo"},
        %{
          codigo: "TR-DA",
          nome: "Trava na dança aberta",
          nota: "Versão aberta da trava. Executada em DA-R, retorna à DA-R."
        },
        %{
          codigo: "ARM-D",
          nome: "Armar pra direita",
          nota:
            "Jogar o CDM do condutor e da conduzida para a direita com intensidade, criando tensão bilateral (elástico). A resolução sempre vem pra esquerda. Saídas: TR-ARM, TR-E."
        },
        %{
          codigo: "TR-ARM",
          nome: "Trava armada",
          nota:
            "Ambos jogam CDM para direita criando elástico. Na virada, condutor cruza direita e conduzida cruza esquerda → trava. Saídas: GP, TRD"
        },
        %{
          codigo: "HF-B2TA",
          nome: "Base 2 Turn Away",
          nota:
            "Saída pós-caminhada: condutor avança o pé direito e gira anti-horário 360° em 3 tempos. A conduzida reverte naturalmente para base 2.",
          wip: true
        },
        %{
          codigo: "HF-R2R",
          nome: "Right to Right Block Block Block",
          nota:
            "Conexão mão direita do condutor com mão direita da conduzida, seguida de três bloqueios consecutivos.",
          wip: true
        },
        %{
          codigo: "HF-S3",
          nome: "Side to Side to Side",
          nota:
            "Bloqueio logo após um giro. Condutor abaixa as mãos para sinalizar. Deslocamento lateral em sequência.",
          wip: true
        },
        %{
          codigo: "HF-AVB",
          nome: "Avião com Bloqueio",
          nota: "Finalização alternativa do avião com um bloqueio.",
          wip: true
        }
      ],
      subsecoes: []
    },
    %{
      titulo: "Pescadas",
      num: 5,
      codigo: "PE",
      descricao:
        "PE é sempre uma finalização. A entrada é rápida, interceptando o movimento antes que ele se complete.",
      nota: "Notação: PE-[perna do condutor]-[perna da conduzida]",
      categoria: "pescadas",
      passos: [
        %{
          codigo: "PE-E-E",
          nome: "Pescada esquerda-esquerda",
          nota: "Fim de caminhada, perna esquerda prende esquerda dela. Saídas: PI, GS, BF"
        },
        %{codigo: "PE-PD", nome: "Pescada com pé duplo", nota: "Variação de entrada"},
        %{codigo: "PE-D-D", nome: "Pescada direita-direita", wip: true},
        %{
          codigo: "HF-ALC",
          nome: "Facão Leg Catch",
          nota: "Captura de perna com facão — floreio decorativo no contexto de uma inversão.",
          wip: true
        },
        %{
          codigo: "HF-FCS",
          nome: "Foot Catch Spin",
          nota: "Giro com captura de pé — combina giro e captura num movimento fluido.",
          wip: true
        }
      ],
      subsecoes: []
    },
    %{
      titulo: "Caminhadas",
      num: 6,
      codigo: "CA",
      descricao: "Deslocamentos frontais, laterais ou diagonais.",
      nota: "A conduzida vai levemente à frente em caminhada — diferente da trava.",
      categoria: "caminhadas",
      passos: [
        %{
          codigo: "CA-E",
          nome: "Caminhada esquerda",
          nota: "Entradas: intenção de sacada, DA-R, SC. Saídas: PE-E-E, SC, BF"
        },
        %{
          codigo: "CA-F",
          nome: "Caminhada frontal",
          nota: "Preferir 45° para a esquerda — condução mais leve. Saídas: PI, PI-INV"
        },
        %{
          codigo: "CA-I",
          nome: "Caminhada Itaúnas",
          nota: "Condutor vai para trás. Preferir condução pequena em músicas rápidas."
        },
        %{
          codigo: "CA-BF",
          nome: "Caminhada/batida frontal",
          nota: "Com ou sem batida traseira em tempo duplo"
        },
        %{
          codigo: "CA-CT",
          nome: "Caminhada com contorno",
          nota:
            "Condutor fica parado, ela contorna e pisa atrás com a esquerda. Retorno com intenção de sacada. Saídas: SC, GP, TRD, TR, CA"
        },
        %{
          codigo: "CA-TZ",
          nome: "Caminhada cruzada com trava final",
          nota: "Primeiro passo da perna direita vai por trás da esquerda, finalizando em trava."
        },
        %{
          codigo: "CA-E-DA",
          nome: "Caminhada esquerda na dança aberta",
          nota: "Versão aberta da caminhada esquerda. Executada em DA-R, retorna à DA-R."
        },
        %{
          codigo: "HF-STS",
          nome: "Side to Slide",
          nota:
            "Deslize lateral alternado. Condutor desliza dir., cruza esq. por trás transferindo peso, libera pé dir. da conduzida para deslizar na direção oposta.",
          wip: true
        },
        %{
          codigo: "HF-CAI",
          nome: "Itaúnas Invertido",
          nota:
            "Condutor muda para tempos 1, 3, 5, 7 (paradiddle). A conduzida mantém base 2 normal. Ciclo de 16 tempos.",
          wip: true
        },
        %{
          codigo: "HF-HHS",
          nome: "Hand to Hand Slide",
          nota: "Deslize da mão direita alta para a mão esquerda da conduzida.",
          wip: true
        },
        %{
          codigo: "HF-CAB",
          nome: "Caminhada Block",
          nota:
            "Caminhada com bloqueio — difícil de dominar. Sacada Reversa (HF-RS) é uma extensão alternativa.",
          wip: true
        }
      ],
      subsecoes: []
    },
    %{
      titulo: "Giro Paulista",
      num: 7,
      codigo: "GP",
      descricao: "Categoria própria — independente dos giros simples.",
      nota: "Todos os paulistas podem sair aberto (-A) ou fechado (-F).",
      categoria: "giros",
      passos: [
        %{
          codigo: "GP",
          nome: "Giro paulista base",
          nota:
            "Entradas: DA-R, PI (ímpar), PMB, TR-ARM, intenção de sacada. Saídas: qualquer base, PI, CA"
        },
        %{
          codigo: "GP-D",
          nome: "Paulista duplo",
          nota: "Ela faz 1,5 giro, condutor executa 5 passos rápidos. Saída sempre fechada (-F)."
        },
        %{
          codigo: "GPE",
          nome: "Giro paulista estranho",
          nota: "Entrada a partir da base estranha (BE)"
        },
        %{
          codigo: "GPC",
          nome: "Giro paulista de costas",
          nota:
            "Paulista executado com os parceiros de costas um para o outro. Exige mais intensidade na condução. Pode ser feito com qualquer mão (esquerda, direita) ou com as duas mãos simultaneamente — neste caso, as mãos geram intensidade para o centro e soltam como um X, criando a rotação. Entrada: GS."
        },
        %{
          codigo: "HF-IP1",
          nome: "Interrupted Paulista 1",
          nota:
            "Paulista interrompido — condutor não solta a mão, posiciona ambos lado a lado. Mão esq. baixa trava a rotação.",
          wip: true
        },
        %{
          codigo: "HF-PRC",
          nome: "Paulista Release Come Back Twist",
          nota:
            "Setup igual ao paulista, mas condutor solta a conexão após o bloqueio. A energia cria giro de 5 passos para a conduzida.",
          wip: true
        },
        %{
          codigo: "HF-PBV",
          nome: "Paulista Variation Bate e Volta",
          nota: "Variação 'bate e volta' — hit and come back.",
          wip: true
        }
      ],
      subsecoes: []
    },
    %{
      titulo: "Inversão",
      num: 8,
      codigo: "IV",
      descricao:
        "Condutor gira a conduzida ao seu redor pela esquerda, mantendo-se no próprio eixo.",
      nota:
        "Sequência: esquerda atrás → direita avança → esquerda à frente. A esquerda à frente gera intenção de sacada. Antigo nome: Facão (FA) — obsoleto.",
      categoria: "inversao",
      passos: [
        %{
          codigo: "IV",
          nome: "Inversão base",
          nota: "Saídas: SC, CA, TR, GP, TRD e qualquer saída via intenção de sacada"
        },
        %{
          codigo: "IV-CT",
          nome: "Finta pós-inversão",
          nota:
            "Simula entrada em caminhada mas joga ela para pisar atrás, puxa de volta. Condução mais circular."
        }
      ],
      subsecoes: []
    },
    %{
      titulo: "Push n pull",
      num: 9,
      codigo: "PU",
      descricao: nil,
      nota: nil,
      categoria: "outros",
      passos: [
        %{codigo: "PU", nome: "Push n pull"},
        %{codigo: "PU-V", nome: "Push n pull com final lateral em V"},
        %{
          codigo: "PU-E-T",
          nome: "Push n pull com esquerda para trás",
          nota: "Pós dissociação de abertura"
        }
      ],
      subsecoes: []
    },
    %{
      titulo: "Dança aberta",
      num: 10,
      codigo: "DA",
      descricao: "Duas versões — forró universitário e forró roots. Distintas em mecânica e uso.",
      nota: nil,
      categoria: "outros",
      passos: [],
      subsecoes: [
        %{
          titulo: "DA-U — Dança aberta universitária",
          nota: "Abertura lateral com pé para trás.",
          passos: [
            %{
              codigo: "DA-U-RE",
              nome: "Repique universitário",
              nota: "Base aberta: abertura com duas mãos, sacada de quadril"
            }
          ]
        },
        %{
          titulo: "DA-R — Dança aberta roots",
          nota:
            "Abertura para frente, usando o quarto tempo do forró. Ativa a intenção de trava via condução firme de mãos e braços.",
          passos: [
            %{
              codigo: "DA-R",
              nome: "Dança aberta roots",
              nota:
                "Base própria: condutor avança pé esquerdo à frente (em vez de recuar). Saídas: CA-E-DA, TR-DA, SCSP-DA. Footwork em dança aberta ainda em catalogação (ver passos HF-*)."
            }
          ]
        }
      ]
    },
    %{
      titulo: "Pião",
      num: 11,
      codigo: "PI",
      descricao: "Giro conjunto frente a frente. Pode ser inserido em qualquer momento da dança.",
      nota:
        "Eixo central espelhado. Ciclo: 3 passos = 1 volta. Regra do ímpar: saídas técnicas só ficam corretas em voltas ímpares.",
      categoria: "giros",
      passos: [
        %{
          codigo: "PI",
          nome: "Pião horário (padrão)",
          nota: "Saídas: GP (ímpar), PE, TR-ARM, TRD"
        },
        %{
          codigo: "PI-INV",
          nome: "Pião anti-horário (invertido)",
          nota: "Combo elegante: PI-INV > CA-F > PI-INV > CA-F"
        }
      ],
      subsecoes: []
    },
    %{
      titulo: "Giros",
      num: 12,
      codigo: "G",
      descricao: "Categoria secundária na dança atual.",
      nota: nil,
      categoria: "giros",
      passos: [],
      subsecoes: [
        %{
          titulo: "Giros simples",
          nota: nil,
          passos: [
            %{codigo: "GS", nome: "Giro simples", nota: "Saídas: BF, AB, MC, PI"},
            %{codigo: "GS-TM", nome: "Trocando de mão no alto"},
            %{codigo: "GS-AL", nome: "Indo para abraço lateral grudado"},
            %{codigo: "GS-ALT", nome: "Trocando ela de lado no abraço lateral"},
            %{codigo: "GS-CH", nome: "Chuveirinho"},
            %{codigo: "GS-CHO", nome: "Chuveirinho no ombro"},
            %{codigo: "GS-MC", nome: "Com mão nas costas", nota: "Saídas: MC"},
            %{
              codigo: "GS-RCP",
              nome: "Rocambole por pescoço",
              nota: "Saída para paulista opcional"
            }
          ]
        },
        %{
          titulo: "Giros de 5 pisadas",
          nota: nil,
          passos: [
            %{codigo: "GM", nome: "Manivela (5 pisadas)"},
            %{codigo: "GN", nome: "Giro ninja (5 pisadas)", wip: true},
            %{codigo: "GPA", nome: "Panamericano (5 pisadas, braço esquerdo)"},
            %{codigo: "GCH", nome: "Giro chicote"},
            %{
              codigo: "HF-MV7",
              nome: "Manivela Variation 7 Steps",
              nota: "Variação em 7 passos — para quem o giro de 5 ficou simples.",
              wip: true
            },
            %{
              codigo: "HF-WO5",
              nome: "Wax On 5 Step Variant",
              nota:
                "Condutor pivota no pé esq. e pisa atrás após o primeiro giro. No passo 2 de 5, mão guia muda para palma direita aberta ('Wax On').",
              wip: true
            }
          ]
        },
        %{
          titulo: "Variações de giro",
          nota: nil,
          passos: [
            %{
              codigo: "HF-PT",
              nome: "Push Turn",
              nota:
                "Giro de empurrão com mudança de direção — condutor bloqueia no tempo 2, conduzida pivota no pé esq. no tempo 4 e retorna.",
              wip: true
            },
            %{
              codigo: "HF-TAS",
              nome: "Turn Away Spin Overhead",
              nota:
                "Logo após um giro: condutor gira no lugar e bloqueia com mão direita por cima. Conduzida gira por baixo do braço.",
              wip: true
            },
            %{
              codigo: "HF-DHS",
              nome: "Double Hand Spin",
              nota:
                "Condutor segura as duas mãos durante o giro. Braços caem para os lados ao finalizar.",
              wip: true
            },
            %{
              codigo: "HF-R2L",
              nome: "Right to Left Spin Continuation",
              nota:
                "Saída pós-giro pela mão direita: condutor pega a mão esq. e continua girando em sentido horário.",
              wip: true
            },
            %{
              codigo: "HF-CPH",
              nome: "Continuation Spin Hand Drop",
              nota: "Variação do R2L: após a continuação do giro, a mão da conduzida cai.",
              wip: true
            },
            %{
              codigo: "HF-HRB",
              nome: "High Right Block Spin",
              nota: "Após um bloqueio, condutor desce a mão direita pelo braço causando um giro.",
              wip: true
            },
            %{
              codigo: "HF-A5T",
              nome: "Avião into 5 Step Turn",
              nota: "Avião seguido de giro de 5 passos. Enganosamente complicado.",
              wip: true
            },
            %{
              codigo: "HF-TAV",
              nome: "Turning Avião",
              nota: "Avião com rotação — muita coisa acontecendo ao mesmo tempo.",
              wip: true
            },
            %{
              codigo: "HF-SPB",
              nome: "The Spin Block",
              nota:
                "Bloqueio combinado com giro — considerado essencial no vocabulário de footwork.",
              wip: true
            }
          ]
        }
      ]
    },
    %{
      titulo: "Arrastes",
      num: 13,
      codigo: "AR",
      descricao: nil,
      nota: nil,
      categoria: "outros",
      passos: [
        %{codigo: "ARD", nome: "Arraste direita"},
        %{codigo: "ARE", nome: "Arraste esquerda"}
      ],
      subsecoes: []
    },
    %{
      titulo: "Mão nas costas",
      num: 14,
      codigo: "MC",
      descricao: nil,
      nota: nil,
      categoria: "outros",
      passos: [
        %{codigo: "MC-FP", nome: "Floreio pezinho com toque no outro lado"},
        %{codigo: "MC-TM", nome: "Troca de mão"},
        %{codigo: "MC-TG", nome: "Troca de mão girando horário com abertura"}
      ],
      subsecoes: []
    },
    %{
      titulo: "Abraço lateral",
      num: 15,
      codigo: "AB",
      descricao: nil,
      nota: nil,
      categoria: "outros",
      passos: [
        %{codigo: "AB-T", nome: "Trocas de lado"},
        %{codigo: "AB-VR", nome: "Volta romântica (todos ângulos)"},
        %{codigo: "AB-RQ", nome: "Rebolada de quadril com ela à direita"},
        %{codigo: "AB-TD", nome: "Troca de pé em tempo duplo"},
      ],
      subsecoes: []
    },
    %{
      titulo: "Cadena",
      num: 16,
      codigo: "CD",
      descricao: nil,
      nota: nil,
      categoria: "outros",
      passos: [
        %{codigo: "CD-D", nome: "Cadena perna direita"},
        %{codigo: "CD-E", nome: "Cadena perna esquerda"}
      ],
      subsecoes: []
    },
    %{
      titulo: "Ginga (extra)",
      num: 17,
      codigo: nil,
      descricao: "A ginga nunca é uma categoria isolada — é um complemento entre parênteses.",
      nota: nil,
      categoria: "outros",
      passos: [
        %{codigo: "(ginga pausa 3 dupla)", nome: "Exemplo de notação"},
        %{codigo: "(ginga pés rápidos preparação sacada)", nome: "Exemplo de notação"}
      ],
      subsecoes: []
    },
    %{
      titulo: "Outros movimentos",
      num: 18,
      codigo: nil,
      descricao: nil,
      nota: nil,
      categoria: "outros",
      passos: [
        %{codigo: "CHQ", nome: "Chique-chique"},
        %{
          codigo: "PMB",
          nome: "Pimba",
          nota:
            "Saída do CHQ. Impulso frontal → conduzida recua → volta para esquerda. Gera intenção de sacada. Saídas: GP, TRD, TR, CA"
        },
        %{codigo: "CHC", nome: "Chique-chique carinhoso"},
        %{
          codigo: "TRD",
          nome: "Trocadilho",
          nota:
            "Saída pós intenção de sacada. Condutor cruza perna direita por trás, conduzida cruza direita pela frente. Entradas: SC, PMB, TR-ARM, CA-CT, IV-CT. Saídas: BF, CA, PI"
        }
      ],
      subsecoes: []
    },
    %{
      titulo: "Footwork & Variações Únicas",
      num: 19,
      codigo: "HF",
      descricao:
        "Passos únicos do @forro_footwork que não se encaixam diretamente nas categorias existentes — musicalidade, decoração, condução ativa ou combinações criativas.",
      nota: "Nomes em inglês são os nomes originais do canal @forro_footwork.",
      categoria: "footwork",
      passos: [
        %{
          codigo: "HF-EN",
          nome: "Vem Neném",
          nota:
            "Mudança de peso em 6 dos 7 passos — a troca no tempo 'morto' é contra-intuitiva mas recompensadora.",
          wip: true
        },
        %{
          codigo: "HF-YNK",
          nome: "Yoink",
          nota: "O condutor 'rouba' o pé da conduzida quando o peso dela está no pé de trás.",
          wip: true
        },
        %{
          codigo: "HF-DD",
          nome: "Double Duckerfly",
          nota:
            "Raro e chamativo. Risco de cotovelos no rosto. Exige prática cuidadosa. Duck + butterfly.",
          wip: true
        },
        %{
          codigo: "HF-PS",
          nome: "Pequeno Salto",
          nota:
            "Condutor faz um pequeno salto enquanto a conduzida recebe sensação de giro contínuo. Variação de musicalidade.",
          wip: true
        },
        %{
          codigo: "HF-CWB",
          nome: "Cowboy Sequence",
          nota: "Chicote + laço com spanish exit entre eles. O chicote é o GCH já catalogado.",
          wip: true
        },
        %{
          codigo: "HF-LF",
          nome: "Leader Faint",
          nota:
            "Deco do condutor: entrada como giro simples, mas condutor desliza a mão direita pelas costas até encontrar a mão dela do outro lado.",
          wip: true
        },
        %{
          codigo: "HF-TDC",
          nome: "Trocadilho do Condutor",
          nota:
            "8 tempos. Condutor pausa parte inferior nos tempos 1-2-3 mas guia com o braço. A conduzida lê a abertura do tronco e pisa para a esquerda.",
          wip: true
        },
        %{
          codigo: "HF-AFI",
          nome: "Active Follower Intercept",
          nota: "A conduzida interrompe ativamente a sugestão do condutor — following ativo.",
          wip: true
        },
        %{
          codigo: "HF-AWK",
          nome: "Armwork for Followers and Leaders",
          nota:
            "Trabalho de braços para conduzidas e condutores. Baseado em masterclass. Não é um passo específico.",
          wip: true
        }
      ],
      subsecoes: []
    },
    %{
      titulo: "Conceitos Técnicos de Condução",
      num: nil,
      codigo: nil,
      descricao:
        "Princípios que explicam a lógica por trás dos movimentos — ferramentas de compreensão e condução.",
      nota: nil,
      categoria: "conceitos",
      passos: [],
      subsecoes: []
    }
  ]

  @conceitos [
    {"Intenção de sacada",
     "Avanço da perna esquerda do condutor entre as pernas da conduzida sem completar a sacada. Gerada em: IV, PMB, BF. Saídas: SC, GP, TRD, TR, CA."},
    {"Elástico",
     "Tensão bilateral quando ambos jogam o CDM na mesma direção simultaneamente. Usado em TR-ARM e TR-ARM-PE."},
    {"Transferência de peso (CDM)",
     "Todo movimento começa com transferência de peso. Sem CDM, não há condução — apenas deslocamento mecânico de braços."},
    {"Quarto tempo do forró",
     "Compasso 2/4. Ciclo base: 3 pisadas + 1 pausa/suspensão. O 4º tempo é o momento de 'decisão' do corpo. Usado em DA-R."},
    {"Frame (quadro)",
     "Estrutura de braços, ombros e tronco entre os parceiros. Transmite a intenção do CDM. Rígido demais trava; mole demais perde a informação."},
    {"Dissociação",
     "Mover tronco e quadril em direções diferentes. Essencial em PU-E-T, giros de 5 pisadas (GM, GPA), IV."},
    {"Condução por abdômen vs. mãos",
     "Dois canais distintos. Abdômen/tronco: mais roots — CDM pela proximidade dos corpos (SCSP). Mãos/braços: mais aberta — DA-R, giros, footwork."}
  ]

  # ---------------------------------------------------------------------------
  # API pública
  # ---------------------------------------------------------------------------

  @doc """
  Executa o seed inicial da enciclopédia. Retorna `:ok` na primeira execução e
  `:already_seeded` nas subsequentes — seguro chamar múltiplas vezes.
  """
  def semear! do
    if Repo.exists?(Categoria) do
      :already_seeded
    else
      {:ok, _} =
        Repo.transaction(fn ->
          cats = semear_categorias!()
          semear_secoes!(cats)
          semear_conceitos!()
        end)

      :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Privado — categorias
  # ---------------------------------------------------------------------------

  defp semear_categorias! do
    Enum.reduce(@categorias, %{}, fn {nome, rotulo, cor}, acc ->
      cat =
        %Categoria{}
        |> Categoria.changeset(%{nome: nome, rotulo: rotulo, cor: cor})
        |> Repo.insert!()

      Map.put(acc, nome, cat.id)
    end)
  end

  # ---------------------------------------------------------------------------
  # Privado — seções, subseções e passos
  # ---------------------------------------------------------------------------

  defp semear_secoes!(cats) do
    @secoes
    |> Enum.with_index(1)
    |> Enum.each(fn {secao_data, posicao} ->
      cat_id = cats[secao_data.categoria]

      secao =
        %Secao{}
        |> Secao.changeset(%{
          titulo: secao_data.titulo,
          codigo: secao_data[:codigo],
          num: secao_data[:num],
          descricao: secao_data[:descricao],
          nota: secao_data[:nota],
          posicao: posicao,
          categoria_id: cat_id
        })
        |> Repo.insert!()

      semear_passos!(secao_data[:passos] || [], secao.id, nil, cat_id)

      (secao_data[:subsecoes] || [])
      |> Enum.with_index(1)
      |> Enum.each(fn {sub_data, spos} ->
        sub =
          %Subsecao{}
          |> Subsecao.changeset(%{
            titulo: sub_data.titulo,
            nota: sub_data[:nota],
            posicao: spos,
            secao_id: secao.id
          })
          |> Repo.insert!()

        semear_passos!(sub_data[:passos] || [], secao.id, sub.id, cat_id)
      end)
    end)
  end

  defp semear_passos!(passos, secao_id, subsecao_id, cat_id) do
    passos
    |> Enum.with_index(1)
    |> Enum.each(fn {passo_data, posicao} ->
      codigo = passo_data.codigo
      wip = Map.get(passo_data, :wip, false) or String.starts_with?(codigo, "HF-")
      caminho_imagem = if codigo in @hf_cards, do: "images/#{codigo}.jpg"

      %Passo{}
      |> Passo.changeset(%{
        codigo: codigo,
        nome: passo_data.nome,
        nota: passo_data[:nota],
        wip: wip,
        caminho_imagem: caminho_imagem,
        status: "publicado",
        posicao: posicao,
        secao_id: secao_id,
        subsecao_id: subsecao_id,
        categoria_id: cat_id
      })
      |> Repo.insert(on_conflict: :nothing, conflict_target: :codigo)
    end)
  end

  # ---------------------------------------------------------------------------
  # Privado — conceitos técnicos
  # ---------------------------------------------------------------------------

  defp semear_conceitos! do
    Enum.each(@conceitos, fn {titulo, descricao} ->
      %ConceitoTecnico{}
      |> ConceitoTecnico.changeset(%{titulo: titulo, descricao: descricao})
      |> Repo.insert!()
    end)
  end
end
