defmodule Forrozin.Repo.Migrations.InserirNovosPassosEConexoes do
  use Ecto.Migration

  # Inserção dos novos passos e de todas as arestas do grafo.
  # Idempotente: ON CONFLICT DO NOTHING nos passos; ON CONFLICT DO UPDATE
  # nas conexões (para preservar/atualizar rótulos sem duplicar).
  #
  # Passos usam JOIN contra categorias/secoes — se essas tabelas estiverem
  # vazias (ambiente de teste sem seed), o INSERT é ignorado silenciosamente.
  #
  # Depende de: 20260413131023_limpar_passos_compostos (já rodou antes desta).

  def up do
    # ── 1. Novos passos (JOIN garante que não insere com categoria_id NULL) ─

    execute("""
    INSERT INTO passos (id, codigo, nome, nota, wip, status, posicao, categoria_id, secao_id, inserted_at, updated_at)
    SELECT gen_random_uuid(), 'BA', 'Balanço',
      'Balanço lateral a partir da base frontal. Gera intenção para sacada de esquerda e para arrastes. Momento de suspensão antes da decisão do movimento seguinte.',
      false, 'publicado', 999, c.id, s.id, NOW(), NOW()
    FROM categorias c, secoes s
    WHERE c.nome = 'bases' AND s.num = 1
    ON CONFLICT (codigo) DO NOTHING
    """)

    execute("""
    INSERT INTO passos (id, codigo, nome, nota, wip, status, posicao, categoria_id, secao_id, inserted_at, updated_at)
    SELECT gen_random_uuid(), 'GPC', 'Giro paulista de costas',
      'Paulista executado com os parceiros de costas um para o outro. Exige mais intensidade na condução. Pode ser feito com qualquer mão (esquerda, direita) ou com as duas mãos simultaneamente — neste caso, as mãos geram intensidade para o centro e soltam como um X, criando a rotação. Entrada: GS.',
      false, 'publicado', 999, c.id, s.id, NOW(), NOW()
    FROM categorias c, secoes s
    WHERE c.nome = 'giros' AND s.num = 7
    ON CONFLICT (codigo) DO NOTHING
    """)

    execute("""
    INSERT INTO passos (id, codigo, nome, nota, wip, status, posicao, categoria_id, secao_id, inserted_at, updated_at)
    SELECT gen_random_uuid(), 'SCSP-DA', 'Sacada sem peso na dança aberta',
      'Versão aberta da sacada sem peso. Executada em DA-R, retorna à DA-R.',
      false, 'publicado', 999, c.id, s.id, NOW(), NOW()
    FROM categorias c, secoes s
    WHERE c.nome = 'sacadas' AND s.num = 3
    ON CONFLICT (codigo) DO NOTHING
    """)

    execute("""
    INSERT INTO passos (id, codigo, nome, nota, wip, status, posicao, categoria_id, secao_id, inserted_at, updated_at)
    SELECT gen_random_uuid(), 'TR-DA', 'Trava na dança aberta',
      'Versão aberta da trava. Executada em DA-R, retorna à DA-R.',
      false, 'publicado', 999, c.id, s.id, NOW(), NOW()
    FROM categorias c, secoes s
    WHERE c.nome = 'travas' AND s.num = 4
    ON CONFLICT (codigo) DO NOTHING
    """)

    execute("""
    INSERT INTO passos (id, codigo, nome, nota, wip, status, posicao, categoria_id, secao_id, inserted_at, updated_at)
    SELECT gen_random_uuid(), 'CA-E-DA', 'Caminhada esquerda na dança aberta',
      'Versão aberta da caminhada esquerda. Executada em DA-R, retorna à DA-R.',
      false, 'publicado', 999, c.id, s.id, NOW(), NOW()
    FROM categorias c, secoes s
    WHERE c.nome = 'caminhadas' AND s.num = 6
    ON CONFLICT (codigo) DO NOTHING
    """)

    # ── 2. Corrigir DA-R ───────────────────────────────────────────────────
    execute("""
    UPDATE passos SET
      nome        = 'Dança aberta roots',
      nota        = 'Base própria: condutor avança pé esquerdo à frente (em vez de recuar). Saídas: CA-E-DA, TR-DA, SCSP-DA. Footwork em dança aberta ainda em catalogação (ver passos HF-*).',
      categoria_id = (SELECT id FROM categorias WHERE nome = 'outros'),
      secao_id     = (SELECT id FROM secoes WHERE num = 10),
      subsecao_id  = (SELECT id FROM subsecoes WHERE titulo = 'DA-R — Dança aberta roots' LIMIT 1),
      updated_at   = NOW()
    WHERE codigo = 'DA-R'
    """)

    # ── 3. Todas as arestas do grafo ───────────────────────────────────────
    # O JOIN garante que arestas para passos inexistentes são silenciosamente
    # ignoradas (sem erros de FK). ON CONFLICT DO UPDATE preserva rótulos.
    execute("""
    WITH codigos (orig, dest, rotulo, descricao) AS (
      VALUES
        ('SC',      'GP',      'Giro paulista da sacada',                    'Sacada completa conduzindo ao paulista — distinto da intenção de sacada.'),
        ('SC',      'TRD',     NULL, NULL),
        ('SC',      'PE-E-E',  NULL, NULL),
        ('SC',      'CA-E',    NULL, NULL),
        ('SC',      'PI',      NULL, NULL),
        ('SC-E',    'PE-E-E',  'Pescada após sacada de esquerda',            'Condutor fica de costas. Pesca esquerda com esquerda.'),
        ('SC-E',    'GP',      NULL, NULL),
        ('DA-R',    'TR-FS',   NULL, NULL),
        ('DA-R',    'TR-FC',   NULL, NULL),
        ('TR-ARM',  'GP',      NULL, NULL),
        ('TR-ARM',  'TRD',     NULL, NULL),
        ('ARM-D',   'TR-ARM',  NULL, NULL),
        ('ARM-D',   'TR-E',    NULL, NULL),
        ('PE-E-E',  'PI',      NULL, NULL),
        ('PE-E-E',  'GS',      NULL, NULL),
        ('PE-E-E',  'BF',      NULL, NULL),
        ('DA-R',    'CA-E',    NULL, NULL),
        ('CA-E',    'PE-E-E',  NULL, NULL),
        ('CA-E',    'SC',      NULL, NULL),
        ('CA-E',    'BF',      NULL, NULL),
        ('CA-F',    'PI',      NULL, NULL),
        ('CA-F',    'PI-INV',  NULL, NULL),
        ('CA-CT',   'SC',      NULL, NULL),
        ('CA-CT',   'GP',      NULL, NULL),
        ('CA-CT',   'TRD',     NULL, NULL),
        ('CA-TZ',   'TR-E',    NULL, NULL),
        ('DA-R',    'CA-E-DA', NULL, NULL),
        ('CA-E-DA', 'DA-R',    NULL, NULL),
        ('DA-R',    'TR-DA',   NULL, NULL),
        ('TR-DA',   'DA-R',    NULL, NULL),
        ('DA-R',    'SCSP-DA', NULL, NULL),
        ('SCSP-DA', 'DA-R',    NULL, NULL),
        ('DA-R',    'GP',      NULL, NULL),
        ('PI',      'GP',      NULL, NULL),
        ('PMB',     'GP',      NULL, NULL),
        ('GP',      'BF',      NULL, NULL),
        ('GP',      'PI',      NULL, NULL),
        ('GP',      'CA-E',    NULL, NULL),
        ('BL',      'GP',      NULL, NULL),
        ('GS',      'GPC',     'Juntos',                                     NULL),
        ('AB-T',    'GP-D',    'Saída para paulista duplo fechado',          'Do abraço lateral (trocas de lado): puxar pela mão, condutor e conduzida saem para GP-D-F.'),
        ('BE',      'GPE',     NULL, NULL),
        ('IV',      'SC',      NULL, NULL),
        ('IV',      'CA-E',    NULL, NULL),
        ('IV',      'GP',      NULL, NULL),
        ('IV',      'TRD',     NULL, NULL),
        ('IV',      'IV-CT',   NULL, NULL),
        ('IV-CT',   'TRD',     NULL, NULL),
        ('PI',      'PE-E-E',  NULL, NULL),
        ('PI',      'TR-ARM',  NULL, NULL),
        ('PI',      'TRD',     NULL, NULL),
        ('BF',      'PI',      NULL, NULL),
        ('BTR',     'PI',      NULL, NULL),
        ('GS',      'BF',      NULL, NULL),
        ('GS',      'PI',      NULL, NULL),
        ('BF',      'BA',      NULL, NULL),
        ('BA',      'SC-E',    NULL, NULL),
        ('BA',      'ARD',     NULL, NULL),
        ('BA',      'ARE',     NULL, NULL),
        ('BF',      'ARD',     NULL, NULL),
        ('BF',      'ARE',     NULL, NULL),
        ('ARD',     'ARE',     NULL, NULL),
        ('ARE',     'ARD',     NULL, NULL),
        ('SCSP',    'TR-E',    'Sacada sem peso saindo para trava esquerda', 'Footwork base 2. Pézin esquerdo bate no 1.'),
        ('TR-E',    'PE-E-E',  'Trava armada com pescada',                   'Condutor permanece à direita após armada. Rouba pé esquerdo da conduzida.'),
        ('CHQ',     'PMB',     NULL, NULL),
        ('PMB',     'TRD',     NULL, NULL),
        ('PMB',     'CA-E',    NULL, NULL),
        ('TRD',     'BF',      NULL, NULL),
        ('TRD',     'CA-E',    NULL, NULL),
        ('TRD',     'PI',      NULL, NULL)
    )
    INSERT INTO conexoes_passos (id, tipo, passo_origem_id, passo_destino_id, rotulo, descricao, inserted_at, updated_at)
    SELECT
      gen_random_uuid(),
      'saida',
      po.id,
      pd.id,
      codigos.rotulo,
      codigos.descricao,
      NOW(),
      NOW()
    FROM codigos
    JOIN passos po ON po.codigo = codigos.orig
    JOIN passos pd ON pd.codigo = codigos.dest
    ON CONFLICT (passo_origem_id, passo_destino_id, tipo) DO UPDATE SET
      rotulo     = COALESCE(EXCLUDED.rotulo,    conexoes_passos.rotulo),
      descricao  = COALESCE(EXCLUDED.descricao, conexoes_passos.descricao),
      updated_at = NOW()
    """)
  end

  def down do
    raise "Irreversível — restaurar a partir do backup JSON se necessário."
  end
end
