defmodule Forrozin.Encyclopedia.Seeder do
  @moduledoc """
  Seed inicial da enciclopédia de forró roots.

  Popula categorias, seções, subseções, passos e conceitos técnicos
  a partir dos dados originais do site HTML. Idempotente: chamadas
  subsequentes retornam `:already_seeded` sem modificar o banco.
  """

  alias Forrozin.Encyclopedia.{Category, TechnicalConcept, Step, Section, Subsection}
  alias Forrozin.Repo

  # Códigos HF com imagem em images/
  @hf_cards ~w(
    HF-2345 HF-A5T HF-AFI HF-ALC HF-AVB HF-AWK HF-B2TA HF-CAB HF-CAI HF-CCS
    HF-CPH HF-CWB HF-DD HF-DHS HF-EN HF-FBD HF-FCS HF-FSC HF-FWS HF-HHS
    HF-HRB HF-IP1 HF-LF HF-MV7 HF-NBE HF-NS HF-PBV HF-PLS HF-PRC HF-PS
    HF-PT HF-R2L HF-R2R HF-RS HF-S3 HF-SCA HF-SLC HF-SPB HF-SRS HF-STD
    HF-STS HF-TAS HF-TAV HF-TDC HF-WO5 HF-YNK
  )

  @categories [
    {"sacadas", "Sacadas", "#c0392b"},
    {"travas", "Travas", "#2980b9"},
    {"caminhadas", "Caminhadas", "#27ae60"},
    {"giros", "Giros", "#8e44ad"},
    {"pescadas", "Pescadas", "#d35400"},
    {"inversao", "Inversão", "#c0392b"},
    {"bases", "Bases", "#16a085"},
    {"outros", "Outros", "#e74c3c"},
    {"footwork", "Forró Footwork", "#e67e22"},
    {"conceitos", "Conceitos", "#f39c12"},
    {"convencoes", "Convenções", "#f1c40f"}
  ]

  @sections [
    %{
      title: "Convenções da Notação",
      num: nil,
      code: nil,
      description: nil,
      note: nil,
      category: "convencoes",
      steps: [],
      subsections: [
        %{
          title: "Direção",
          note: nil,
          steps: [
            %{code: "D", name: "Direita"},
            %{code: "E", name: "Esquerda"},
            %{code: "F", name: "Frente"},
            %{code: "T", name: "Trás"}
          ]
        },
        %{
          title: "Pé Duplo",
          note: nil,
          steps: [
            %{code: "pd(ca-fr)", name: "Calcanhar → Frente"},
            %{code: "pd(fr-ca)", name: "Frente → Calcanhar"}
          ]
        },
        %{
          title: "Saídas de Giros Paulistas",
          note:
            "Todos os paulistas (GP, GPE, GPC) podem sair aberto ou fechado — sufixos opcionais.",
          steps: [
            %{code: "-A", name: "Saída aberta"},
            %{code: "-F", name: "Saída fechada"},
            %{code: "-PC", name: "Saída pelas costas", wip: true}
          ]
        }
      ]
    },
    %{
      title: "Bases",
      num: 1,
      code: "B",
      description: "Movimentos essenciais, usados como ponto de partida para combinações.",
      note: nil,
      category: "bases",
      steps: [
        %{code: "BTR", name: "Base triangular"},
        %{code: "BF", name: "Base frontal"},
        %{
          code: "BFR",
          name: "Base frontal romântica",
          note: "Com arraste lateral e ginga suave"
        },
        %{code: "BQ", name: "Base quadrada"},
        %{code: "BL", name: "Base lateral", note: "Com aberturas e variações"},
        %{
          code: "BE",
          name: "Base estranha",
          note:
            "Pé direito vai à frente (em vez de trás) ao voltar ao meio — condutor invade o espaço da conduzida. Função: habilitar GPE."
        },
        %{
          code: "BA",
          name: "Balanço",
          note:
            "Balanço lateral a partir da base frontal. Gera intenção para sacada de esquerda e para arrastes. Momento de suspensão antes da decisão do movimento seguinte."
        }
      ],
      subsections: []
    },
    %{
      title: "Sacadas",
      num: 2,
      code: "SC",
      description: "Movimento de interceptação de espaço ou de perna.",
      note: nil,
      category: "sacadas",
      steps: [
        %{
          code: "SC",
          name: "Sacada simples",
          note:
            "Transferência, pé por baixo, coxa. Entradas: intenção de sacada. Saídas: GP, TRD, PE, CA, PI"
        },
        %{
          code: "SC-E",
          name: "Sacada de esquerda",
          note: "Mecânica própria — não depende da intenção de sacada padrão. Saídas: PE-E-E, GP"
        },
        %{
          code: "SCxX",
          name: "Sacada múltipla (sacadas alternadas)",
          note:
            "Sacadas alternadas em sequência — exige coordenação precisa de ambos os parceiros."
        },
        %{
          code: "HF-SRS",
          name: "Suspended Rotating Sacada",
          note:
            "Sacada rotativa suspensa — perna sacada fica suspensa até o tempo 5 do próximo compasso. Leve pausa durante a rotação.",
          wip: true
        },
        %{
          code: "HF-RS",
          name: "Reverse Sacada",
          note:
            "Sacada reversa — extensão ou finalização alternativa da Caminhada Block (HF-CAB).",
          wip: true
        },
        %{
          code: "HF-NS",
          name: "Pêndulo Sacada",
          note:
            "Deslize lateral combinado com Pêndulo. 5 passos sem pausa, ou com pausa. Seguido por sacadas repetidas em 1-3, 1-3.",
          wip: true
        },
        %{
          code: "HF-CCS",
          name: "Cha Cha Sacada",
          note:
            "Versão estendida da Sacada com Arrastada: sacada esq. → sacada dir. → e de volta.",
          wip: true
        },
        %{
          code: "HF-FSC",
          name: "Follower Sacada",
          note: "A conduzida executa a sacada — following ativo.",
          wip: true
        },
        %{
          code: "HF-SCA",
          name: "Sacada com Arrastada",
          note:
            "Condutor cruza as pernas no passo recuado e usa a coxa esquerda para a sacada, seguida de arraste do pé.",
          wip: true
        },
        %{
          code: "HF-SLC",
          name: "Sacada Leg Catch",
          note:
            "Sacada com captura de perna — arriscado (canela da conduzida). Praticar sem sapatos.",
          wip: true
        },
        %{
          code: "HF-STD",
          name: "Sacada de Trava Deco",
          note:
            "Condutor cruza pé direito por trás, libera espaço para varredura com o pé esquerdo. Conduzida aproveita com a perna direita.",
          wip: true
        },
        %{
          code: "HF-PLS",
          name: "Pêndulo Lateral + Sacada + Caminhada com Pausa",
          note: "Das mais estilosas: pêndulo lateral encadeado com sacada e caminhada com pausa.",
          wip: true
        }
      ],
      subsections: []
    },
    %{
      title: "Sacada sem peso",
      num: 3,
      code: "SCSP",
      description: nil,
      note:
        "A condução parte do abdômen e ombro, não do pé. Sempre com 4 tempos de footwork antes da saída em chassê. Antigo name: CH (Chutinho) — obsoleto.",
      category: "sacadas",
      steps: [
        %{code: "SCSP", name: "Sacada sem peso", note: "Saída em chassê"},
        %{
          code: "SCSP-BE",
          name: "Com pézin esquerdo batendo 1",
          note: "Seguido de balanço para esquerda (footwork base 1)"
        },
        %{
          code: "SCSP-PDI-ET-BE",
          name: "Falso balanço esquerdo",
          note: "Finalização de pé direito para dentro, pé esquerdo por trás do direito"
        },
        %{
          code: "SCSP-TP",
          name: "Com troca rápida",
          note: "Troca rápida pela direita antes do balanço esquerda"
        },
        %{
          code: "SCSP-MD",
          name: "Marca duplo saída mão cruzada",
          note: "Marca duplo com esquerda pd(ca-fr)-E, entra girando esquerda"
        },
        %{
          code: "SCSP-DA",
          name: "Sacada sem peso na dança aberta",
          note: "Versão aberta da sacada sem peso. Executada em DA-R, retorna à DA-R."
        }
      ],
      subsections: []
    },
    %{
      title: "Travas",
      num: 4,
      code: "TR",
      description: "Travamentos de perna, podem ter sacada ou não.",
      note:
        "Em trava a perna do condutor vai à frente. O V da abertura entre os parceiros não pode ser muito grande.",
      category: "travas",
      steps: [
        %{code: "TR-E", name: "Trava esquerda"},
        %{
          code: "TR-FS",
          name: "Trava frontal sem sacada",
          note: "Entradas: DA-R, intenção de sacada"
        },
        %{
          code: "TR-FC",
          name: "Trava frontal com sacada",
          note: "Entradas: DA-R, intenção de sacada"
        },
        %{code: "TR-P3", name: "Trava com pezinho no terceiro tempo"},
        %{
          code: "TR-DA",
          name: "Trava na dança aberta",
          note: "Versão aberta da trava. Executada em DA-R, retorna à DA-R."
        },
        %{
          code: "ARM-D",
          name: "Armar pra direita",
          note:
            "Jogar o CDM do condutor e da conduzida para a direita com intensidade, criando tensão bilateral (elástico). A resolução sempre vem pra esquerda. Saídas: TR-ARM, TR-E."
        },
        %{
          code: "TR-ARM",
          name: "Trava armada",
          note:
            "Ambos jogam CDM para direita criando elástico. Na virada, condutor cruza direita e conduzida cruza esquerda → trava. Saídas: GP, TRD"
        },
        %{
          code: "HF-B2TA",
          name: "Base 2 Turn Away",
          note:
            "Saída pós-caminhada: condutor avança o pé direito e gira anti-horário 360° em 3 tempos. A conduzida reverte naturalmente para base 2.",
          wip: true
        },
        %{
          code: "HF-R2R",
          name: "Right to Right Block Block Block",
          note:
            "Conexão mão direita do condutor com mão direita da conduzida, seguida de três bloqueios consecutivos.",
          wip: true
        },
        %{
          code: "HF-S3",
          name: "Side to Side to Side",
          note:
            "Bloqueio logo após um giro. Condutor abaixa as mãos para sinalizar. Deslocamento lateral em sequência.",
          wip: true
        },
        %{
          code: "HF-AVB",
          name: "Avião com Bloqueio",
          note: "Finalização alternativa do avião com um bloqueio.",
          wip: true
        }
      ],
      subsections: []
    },
    %{
      title: "Pescadas",
      num: 5,
      code: "PE",
      description:
        "PE é sempre uma finalização. A entrada é rápida, interceptando o movimento antes que ele se complete.",
      note: "Notação: PE-[perna do condutor]-[perna da conduzida]",
      category: "pescadas",
      steps: [
        %{
          code: "PE-E-E",
          name: "Pescada esquerda-esquerda",
          note: "Fim de caminhada, perna esquerda prende esquerda dela. Saídas: PI, GS, BF"
        },
        %{code: "PE-PD", name: "Pescada com pé duplo", note: "Variação de entrada"},
        %{code: "PE-D-D", name: "Pescada direita-direita", wip: true},
        %{
          code: "HF-ALC",
          name: "Facão Leg Catch",
          note: "Captura de perna com facão — floreio decorativo no contexto de uma inversão.",
          wip: true
        },
        %{
          code: "HF-FCS",
          name: "Foot Catch Spin",
          note: "Giro com captura de pé — combina giro e captura num movimento fluido.",
          wip: true
        }
      ],
      subsections: []
    },
    %{
      title: "Caminhadas",
      num: 6,
      code: "CA",
      description: "Deslocamentos frontais, laterais ou diagonais.",
      note: "A conduzida vai levemente à frente em caminhada — diferente da trava.",
      category: "caminhadas",
      steps: [
        %{
          code: "CA-E",
          name: "Caminhada esquerda",
          note: "Entradas: intenção de sacada, DA-R, SC. Saídas: PE-E-E, SC, BF"
        },
        %{
          code: "CA-F",
          name: "Caminhada frontal",
          note: "Preferir 45° para a esquerda — condução mais leve. Saídas: PI, PI-INV"
        },
        %{
          code: "CA-I",
          name: "Caminhada Itaúnas",
          note: "Condutor vai para trás. Preferir condução pequena em músicas rápidas."
        },
        %{
          code: "CA-BF",
          name: "Caminhada/batida frontal",
          note: "Com ou sem batida traseira em tempo duplo"
        },
        %{
          code: "CA-CT",
          name: "Caminhada com contorno",
          note:
            "Condutor fica parado, ela contorna e pisa atrás com a esquerda. Retorno com intenção de sacada. Saídas: SC, GP, TRD, TR, CA"
        },
        %{
          code: "CA-TZ",
          name: "Caminhada cruzada com trava final",
          note: "Primeiro passo da perna direita vai por trás da esquerda, finalizando em trava."
        },
        %{
          code: "CA-E-DA",
          name: "Caminhada esquerda na dança aberta",
          note: "Versão aberta da caminhada esquerda. Executada em DA-R, retorna à DA-R."
        },
        %{
          code: "HF-STS",
          name: "Side to Slide",
          note:
            "Deslize lateral alternado. Condutor desliza dir., cruza esq. por trás transferindo peso, libera pé dir. da conduzida para deslizar na direção oposta.",
          wip: true
        },
        %{
          code: "HF-CAI",
          name: "Itaúnas Invertido",
          note:
            "Condutor muda para tempos 1, 3, 5, 7 (paradiddle). A conduzida mantém base 2 normal. Ciclo de 16 tempos.",
          wip: true
        },
        %{
          code: "HF-HHS",
          name: "Hand to Hand Slide",
          note: "Deslize da mão direita alta para a mão esquerda da conduzida.",
          wip: true
        },
        %{
          code: "HF-CAB",
          name: "Caminhada Block",
          note:
            "Caminhada com bloqueio — difícil de dominar. Sacada Reversa (HF-RS) é uma extensão alternativa.",
          wip: true
        }
      ],
      subsections: []
    },
    %{
      title: "Giro Paulista",
      num: 7,
      code: "GP",
      description: "Categoria própria — independente dos giros simples.",
      note: "Todos os paulistas podem sair aberto (-A) ou fechado (-F).",
      category: "giros",
      steps: [
        %{
          code: "GP",
          name: "Giro paulista base",
          note:
            "Entradas: DA-R, PI (ímpar), PMB, TR-ARM, intenção de sacada. Saídas: qualquer base, PI, CA"
        },
        %{
          code: "GP-D",
          name: "Paulista duplo",
          note: "Ela faz 1,5 giro, condutor executa 5 passos rápidos. Saída sempre fechada (-F)."
        },
        %{
          code: "GPE",
          name: "Giro paulista estranho",
          note: "Entrada a partir da base estranha (BE)"
        },
        %{
          code: "GPC",
          name: "Giro paulista de costas",
          note:
            "Paulista executado com os parceiros de costas um para o outro. Exige mais intensidade na condução. Pode ser feito com qualquer mão (esquerda, direita) ou com as duas mãos simultaneamente — neste caso, as mãos geram intensidade para o centro e soltam como um X, criando a rotação. Entrada: GS."
        },
        %{
          code: "HF-IP1",
          name: "Interrupted Paulista 1",
          note:
            "Paulista interrompido — condutor não solta a mão, posiciona ambos lado a lado. Mão esq. baixa trava a rotação.",
          wip: true
        },
        %{
          code: "HF-PRC",
          name: "Paulista Release Come Back Twist",
          note:
            "Setup igual ao paulista, mas condutor solta a conexão após o bloqueio. A energia cria giro de 5 passos para a conduzida.",
          wip: true
        },
        %{
          code: "HF-PBV",
          name: "Paulista Variation Bate e Volta",
          note: "Variação 'bate e volta' — hit and come back.",
          wip: true
        }
      ],
      subsections: []
    },
    %{
      title: "Inversão",
      num: 8,
      code: "IV",
      description:
        "Condutor gira a conduzida ao seu redor pela esquerda, mantendo-se no próprio eixo.",
      note:
        "Sequência: esquerda atrás → direita avança → esquerda à frente. A esquerda à frente gera intenção de sacada. Antigo name: Facão (FA) — obsoleto.",
      category: "inversao",
      steps: [
        %{
          code: "IV",
          name: "Inversão base",
          note: "Saídas: SC, CA, TR, GP, TRD e qualquer saída via intenção de sacada"
        },
        %{
          code: "IV-CT",
          name: "Finta pós-inversão",
          note:
            "Simula entrada em caminhada mas joga ela para pisar atrás, puxa de volta. Condução mais circular."
        }
      ],
      subsections: []
    },
    %{
      title: "Push n pull",
      num: 9,
      code: "PU",
      description: nil,
      note: nil,
      category: "outros",
      steps: [
        %{code: "PU", name: "Push n pull"},
        %{code: "PU-V", name: "Push n pull com final lateral em V"},
        %{
          code: "PU-E-T",
          name: "Push n pull com esquerda para trás",
          note: "Pós dissociação de abertura"
        }
      ],
      subsections: []
    },
    %{
      title: "Dança aberta",
      num: 10,
      code: "DA",
      description: "Duas versões — forró universitário e forró roots. Distintas em mecânica e uso.",
      note: nil,
      category: "outros",
      steps: [],
      subsections: [
        %{
          title: "DA-U — Dança aberta universitária",
          note: "Abertura lateral com pé para trás.",
          steps: [
            %{
              code: "DA-U-RE",
              name: "Repique universitário",
              note: "Base aberta: abertura com duas mãos, sacada de quadril"
            }
          ]
        },
        %{
          title: "DA-R — Dança aberta roots",
          note:
            "Abertura para frente, usando o quarto tempo do forró. Ativa a intenção de trava via condução firme de mãos e braços.",
          steps: [
            %{
              code: "DA-R",
              name: "Dança aberta roots",
              note:
                "Base própria: condutor avança pé esquerdo à frente (em vez de recuar). Saídas: CA-E-DA, TR-DA, SCSP-DA. Footwork em dança aberta ainda em catalogação (ver passos HF-*)."
            }
          ]
        }
      ]
    },
    %{
      title: "Pião",
      num: 11,
      code: "PI",
      description: "Giro conjunto frente a frente. Pode ser inserido em qualquer momento da dança.",
      note:
        "Eixo central espelhado. Ciclo: 3 passos = 1 volta. Regra do ímpar: saídas técnicas só ficam corretas em voltas ímpares.",
      category: "giros",
      steps: [
        %{
          code: "PI",
          name: "Pião horário (padrão)",
          note: "Saídas: GP (ímpar), PE, TR-ARM, TRD"
        },
        %{
          code: "PI-INV",
          name: "Pião anti-horário (invertido)",
          note: "Combo elegante: PI-INV > CA-F > PI-INV > CA-F"
        }
      ],
      subsections: []
    },
    %{
      title: "Giros",
      num: 12,
      code: "G",
      description: "Categoria secundária na dança atual.",
      note: nil,
      category: "giros",
      steps: [],
      subsections: [
        %{
          title: "Giros simples",
          note: nil,
          steps: [
            %{code: "GS", name: "Giro simples", note: "Saídas: BF, AB, MC, PI"},
            %{code: "GS-TM", name: "Trocando de mão no alto"},
            %{code: "GS-AL", name: "Indo para abraço lateral grudado"},
            %{code: "GS-ALT", name: "Trocando ela de lado no abraço lateral"},
            %{code: "GS-CH", name: "Chuveirinho"},
            %{code: "GS-CHO", name: "Chuveirinho no ombro"},
            %{code: "GS-MC", name: "Com mão nas costas", note: "Saídas: MC"},
            %{
              code: "GS-RCP",
              name: "Rocambole por pescoço",
              note: "Saída para paulista opcional"
            }
          ]
        },
        %{
          title: "Giros de 5 pisadas",
          note: nil,
          steps: [
            %{code: "GM", name: "Manivela (5 pisadas)"},
            %{code: "GN", name: "Giro ninja (5 pisadas)", wip: true},
            %{code: "GPA", name: "Panamericano (5 pisadas, braço esquerdo)"},
            %{code: "GCH", name: "Giro chicote"},
            %{
              code: "HF-MV7",
              name: "Manivela Variation 7 Steps",
              note: "Variação em 7 passos — para quem o giro de 5 ficou simples.",
              wip: true
            },
            %{
              code: "HF-WO5",
              name: "Wax On 5 Step Variant",
              note:
                "Condutor pivota no pé esq. e pisa atrás após o primeiro giro. No passo 2 de 5, mão guia muda para palma direita aberta ('Wax On').",
              wip: true
            }
          ]
        },
        %{
          title: "Variações de giro",
          note: nil,
          steps: [
            %{
              code: "HF-PT",
              name: "Push Turn",
              note:
                "Giro de empurrão com mudança de direção — condutor bloqueia no tempo 2, conduzida pivota no pé esq. no tempo 4 e retorna.",
              wip: true
            },
            %{
              code: "HF-TAS",
              name: "Turn Away Spin Overhead",
              note:
                "Logo após um giro: condutor gira no lugar e bloqueia com mão direita por cima. Conduzida gira por baixo do braço.",
              wip: true
            },
            %{
              code: "HF-DHS",
              name: "Double Hand Spin",
              note:
                "Condutor segura as duas mãos durante o giro. Braços caem para os lados ao finalizar.",
              wip: true
            },
            %{
              code: "HF-R2L",
              name: "Right to Left Spin Continuation",
              note:
                "Saída pós-giro pela mão direita: condutor pega a mão esq. e continua girando em sentido horário.",
              wip: true
            },
            %{
              code: "HF-CPH",
              name: "Continuation Spin Hand Drop",
              note: "Variação do R2L: após a continuação do giro, a mão da conduzida cai.",
              wip: true
            },
            %{
              code: "HF-HRB",
              name: "High Right Block Spin",
              note: "Após um bloqueio, condutor desce a mão direita pelo braço causando um giro.",
              wip: true
            },
            %{
              code: "HF-A5T",
              name: "Avião into 5 Step Turn",
              note: "Avião seguido de giro de 5 passos. Enganosamente complicado.",
              wip: true
            },
            %{
              code: "HF-TAV",
              name: "Turning Avião",
              note: "Avião com rotação — muita coisa acontecendo ao mesmo tempo.",
              wip: true
            },
            %{
              code: "HF-SPB",
              name: "The Spin Block",
              note:
                "Bloqueio combinado com giro — considerado essencial no vocabulário de footwork.",
              wip: true
            }
          ]
        }
      ]
    },
    %{
      title: "Arrastes",
      num: 13,
      code: "AR",
      description: nil,
      note: nil,
      category: "outros",
      steps: [
        %{code: "ARD", name: "Arraste direita"},
        %{code: "ARE", name: "Arraste esquerda"}
      ],
      subsections: []
    },
    %{
      title: "Mão nas costas",
      num: 14,
      code: "MC",
      description: nil,
      note: nil,
      category: "outros",
      steps: [
        %{code: "MC-FP", name: "Floreio pezinho com toque no outro lado"},
        %{code: "MC-TM", name: "Troca de mão"},
        %{code: "MC-TG", name: "Troca de mão girando horário com abertura"}
      ],
      subsections: []
    },
    %{
      title: "Abraço lateral",
      num: 15,
      code: "AB",
      description: nil,
      note: nil,
      category: "outros",
      steps: [
        %{code: "AB-T", name: "Trocas de lado"},
        %{code: "AB-VR", name: "Volta romântica (todos ângulos)"},
        %{code: "AB-RQ", name: "Rebolada de quadril com ela à direita"},
        %{code: "AB-TD", name: "Troca de pé em tempo duplo"},
      ],
      subsections: []
    },
    %{
      title: "Cadena",
      num: 16,
      code: "CD",
      description: nil,
      note: nil,
      category: "outros",
      steps: [
        %{code: "CD-D", name: "Cadena perna direita"},
        %{code: "CD-E", name: "Cadena perna esquerda"}
      ],
      subsections: []
    },
    %{
      title: "Ginga (extra)",
      num: 17,
      code: nil,
      description: "A ginga nunca é uma categoria isolada — é um complemento entre parênteses.",
      note: nil,
      category: "outros",
      steps: [
        %{code: "(ginga pausa 3 dupla)", name: "Exemplo de notação"},
        %{code: "(ginga pés rápidos preparação sacada)", name: "Exemplo de notação"}
      ],
      subsections: []
    },
    %{
      title: "Outros movimentos",
      num: 18,
      code: nil,
      description: nil,
      note: nil,
      category: "outros",
      steps: [
        %{code: "CHQ", name: "Chique-chique"},
        %{
          code: "PMB",
          name: "Pimba",
          note:
            "Saída do CHQ. Impulso frontal → conduzida recua → volta para esquerda. Gera intenção de sacada. Saídas: GP, TRD, TR, CA"
        },
        %{code: "CHC", name: "Chique-chique carinhoso"},
        %{
          code: "TRD",
          name: "Trocadilho",
          note:
            "Saída pós intenção de sacada. Condutor cruza perna direita por trás, conduzida cruza direita pela frente. Entradas: SC, PMB, TR-ARM, CA-CT, IV-CT. Saídas: BF, CA, PI"
        }
      ],
      subsections: []
    },
    %{
      title: "Footwork & Variações Únicas",
      num: 19,
      code: "HF",
      description:
        "Passos únicos do @forro_footwork que não se encaixam diretamente nas categorias existentes — musicalidade, decoração, condução ativa ou combinações criativas.",
      note: "Nomes em inglês são os nomes originais do canal @forro_footwork.",
      category: "footwork",
      steps: [
        %{
          code: "HF-EN",
          name: "Vem Neném",
          note:
            "Mudança de peso em 6 dos 7 passos — a troca no tempo 'morto' é contra-intuitiva mas recompensadora.",
          wip: true
        },
        %{
          code: "HF-YNK",
          name: "Yoink",
          note: "O condutor 'rouba' o pé da conduzida quando o peso dela está no pé de trás.",
          wip: true
        },
        %{
          code: "HF-DD",
          name: "Double Duckerfly",
          note:
            "Raro e chamativo. Risco de cotovelos no rosto. Exige prática cuidadosa. Duck + butterfly.",
          wip: true
        },
        %{
          code: "HF-PS",
          name: "Pequeno Salto",
          note:
            "Condutor faz um pequeno salto enquanto a conduzida recebe sensação de giro contínuo. Variação de musicalidade.",
          wip: true
        },
        %{
          code: "HF-CWB",
          name: "Cowboy Sequence",
          note: "Chicote + laço com spanish exit entre eles. O chicote é o GCH já catalogado.",
          wip: true
        },
        %{
          code: "HF-LF",
          name: "Leader Faint",
          note:
            "Deco do condutor: entrada como giro simples, mas condutor desliza a mão direita pelas costas até encontrar a mão dela do outro lado.",
          wip: true
        },
        %{
          code: "HF-TDC",
          name: "Trocadilho do Condutor",
          note:
            "8 tempos. Condutor pausa parte inferior nos tempos 1-2-3 mas guia com o braço. A conduzida lê a abertura do tronco e pisa para a esquerda.",
          wip: true
        },
        %{
          code: "HF-AFI",
          name: "Active Follower Intercept",
          note: "A conduzida interrompe ativamente a sugestão do condutor — following ativo.",
          wip: true
        },
        %{
          code: "HF-AWK",
          name: "Armwork for Followers and Leaders",
          note:
            "Trabalho de braços para conduzidas e condutores. Baseado em masterclass. Não é um passo específico.",
          wip: true
        }
      ],
      subsections: []
    },
    %{
      title: "Conceitos Técnicos de Condução",
      num: nil,
      code: nil,
      description:
        "Princípios que explicam a lógica por trás dos movimentos — ferramentas de compreensão e condução.",
      note: nil,
      category: "conceitos",
      steps: [],
      subsections: []
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
  def seed! do
    if Repo.exists?(Category) do
      :already_seeded
    else
      {:ok, _} =
        Repo.transaction(fn ->
          categories_map = seed_categories!()
          seed_sections!(categories_map)
          seed_technical_concepts!()
        end)

      :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Privado — categorias
  # ---------------------------------------------------------------------------

  defp seed_categories! do
    Enum.reduce(@categories, %{}, fn {name, label, color}, acc ->
      cat =
        %Category{}
        |> Category.changeset(%{name: name, label: label, color: color})
        |> Repo.insert!()

      Map.put(acc, name, cat.id)
    end)
  end

  # ---------------------------------------------------------------------------
  # Privado — seções, subseções e passos
  # ---------------------------------------------------------------------------

  defp seed_sections!(categories_map) do
    @sections
    |> Enum.with_index(1)
    |> Enum.each(fn {section_data, position} ->
      cat_id = categories_map[section_data.category]

      section =
        %Section{}
        |> Section.changeset(%{
          title: section_data.title,
          code: section_data[:code],
          num: section_data[:num],
          description: section_data[:description],
          note: section_data[:note],
          position: position,
          category_id: cat_id
        })
        |> Repo.insert!()

      seed_steps!(section_data[:steps] || [], section.id, nil, cat_id)

      (section_data[:subsections] || [])
      |> Enum.with_index(1)
      |> Enum.each(fn {subsection_data, sub_position} ->
        subsection =
          %Subsection{}
          |> Subsection.changeset(%{
            title: subsection_data.title,
            note: subsection_data[:note],
            position: sub_position,
            section_id: section.id
          })
          |> Repo.insert!()

        seed_steps!(subsection_data[:steps] || [], section.id, subsection.id, cat_id)
      end)
    end)
  end

  defp seed_steps!(steps, section_id, subsection_id, cat_id) do
    steps
    |> Enum.with_index(1)
    |> Enum.each(fn {step_data, position} ->
      code = step_data.code
      wip = Map.get(step_data, :wip, false) or String.starts_with?(code, "HF-")
      image_path = if code in @hf_cards, do: "images/#{code}.jpg"

      %Step{}
      |> Step.changeset(%{
        code: code,
        name: step_data.name,
        note: step_data[:note],
        wip: wip,
        image_path: image_path,
        status: "published",
        position: position,
        section_id: section_id,
        subsection_id: subsection_id,
        category_id: cat_id
      })
      |> Repo.insert(on_conflict: :nothing, conflict_target: :code)
    end)
  end

  # ---------------------------------------------------------------------------
  # Privado — conceitos técnicos
  # ---------------------------------------------------------------------------

  defp seed_technical_concepts! do
    Enum.each(@conceitos, fn {titulo, descricao} ->
      %TechnicalConcept{}
      |> TechnicalConcept.changeset(%{title: titulo, description: descricao})
      |> Repo.insert!()
    end)
  end
end
