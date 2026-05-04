defmodule OGrupoDeEstudos.Repo.Migrations.EnrichStepVideoLinks do
  use Ecto.Migration

  @moduledoc """
  Migration 3/3 do enriquecimento de dados via GPT.

  Adiciona 11 novos links de vídeo (YouTube) a 6 passos distintos.
  Todos são links novos que não existiam no banco.

  Nota sobre URLs compartilhadas:
    - Hb0_tU0Ress aparece em 6 passos (CA-E, CA-F, CA-I, GP, IV, PI)
      → provavelmente um vídeo geral mostrando múltiplos passos
    - uuGQHIcOC88 aparece em 2 passos (IV, PI)
      → provavelmente um vídeo que demonstra ambos

  submitted_by_id: admin (sistema)
  approved: true (links curados pelo GPT a partir de fontes conhecidas)

  Fonte: ~/Downloads/passos_forro.json (saída do GPT em 2026-05-04)
  """

  def up do
    # ──────────────────────────────────────────────────────────────────────────
    # 11 NOVOS LINKS DE VÍDEO
    # ──────────────────────────────────────────────────────────────────────────

    links = [
      # BF — Base frontal (já tem 1 link, ganha mais 2)
      {"BF", "Base frontal — demonstração", "https://www.youtube.com/watch?v=y626yL_IPxY"},
      {"BF", "Base frontal — variação", "https://www.youtube.com/watch?v=1l2ED87Hi4E"},

      # CA-E — Caminhada esquerda
      {"CA-E", "Caminhadas e deslocamentos", "https://www.youtube.com/watch?v=Hb0_tU0Ress"},

      # CA-F — Caminhada frontal
      {"CA-F", "Caminhadas e deslocamentos", "https://www.youtube.com/watch?v=Hb0_tU0Ress"},

      # CA-I — Caminhada em linha
      {"CA-I", "Caminhadas e deslocamentos", "https://www.youtube.com/watch?v=Hb0_tU0Ress"},

      # GP — Giro paulista
      {"GP", "Giro paulista — aula completa", "https://www.youtube.com/watch?v=_izNDZz-udE"},
      {"GP", "Giro paulista em contexto", "https://www.youtube.com/watch?v=Hb0_tU0Ress"},

      # IV — Inversão
      {"IV", "Inversão e deslocamentos", "https://www.youtube.com/watch?v=Hb0_tU0Ress"},
      {"IV", "Inversão e pião", "https://www.youtube.com/watch?v=uuGQHIcOC88"},

      # PI — Pião
      {"PI", "Pião em contexto", "https://www.youtube.com/watch?v=Hb0_tU0Ress"},
      {"PI", "Pião e inversão", "https://www.youtube.com/watch?v=uuGQHIcOC88"}
    ]

    for {code, title, url} <- links do
      escaped_title = String.replace(title, "'", "''")

      execute("""
      INSERT INTO step_links (id, url, title, approved, step_id, submitted_by_id, inserted_at, updated_at)
      SELECT
        gen_random_uuid(),
        '#{url}',
        '#{escaped_title}',
        true,
        s.id,
        (SELECT id FROM users WHERE role = 'admin' LIMIT 1),
        NOW(),
        NOW()
      FROM steps s
      WHERE s.code = '#{code}'
        AND s.deleted_at IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM step_links sl
          WHERE sl.step_id = s.id AND sl.url = '#{url}' AND sl.deleted_at IS NULL
        )
      """)
    end
  end

  def down do
    # Remove os 11 links adicionados (identificados pela URL)
    urls = [
      "https://www.youtube.com/watch?v=y626yL_IPxY",
      "https://www.youtube.com/watch?v=1l2ED87Hi4E",
      "https://www.youtube.com/watch?v=Hb0_tU0Ress",
      "https://www.youtube.com/watch?v=_izNDZz-udE",
      "https://www.youtube.com/watch?v=uuGQHIcOC88"
    ]

    values = Enum.map_join(urls, ", ", &"'#{&1}'")

    execute("""
    DELETE FROM step_links WHERE url IN (#{values})
    """)
  end
end
