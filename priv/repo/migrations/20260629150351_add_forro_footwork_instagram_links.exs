defmodule OGrupoDeEstudos.Repo.Migrations.AddForroFootworkInstagramLinks do
  use Ecto.Migration

  # Mapeamento manual dos posts do @forro_footwork (cada arte traz o nome do
  # passo). Idempotente e referenciado por `code` (estavel entre dev/prod),
  # nunca por id. `strpos` (substring literal) evita que o `_` dos shortcodes
  # seja tratado como wildcard do LIKE.

  # Passos que estavam sem o link correto: inserir o post oficial como link
  # aprovado. HF-PS (Pequeno Salto) tinha apenas um link ERRADO (movido abaixo);
  # o post correto do Pequeno Salto estava sem cadastro, entao entra aqui.
  @insert [
    {"HF-AFI", "C_u6G8EOQJm"},
    {"HF-AVB", "C4BSG5kts2X"},
    {"HF-CAI", "C9U5CLJN0T5"},
    {"HF-CPH", "C4iY6wON2EA"},
    {"HF-DHS", "CzY3UhYtsON"},
    {"HF-FSC", "C1b_-LaNqFc"},
    {"HF-LF", "C6EfbXytSNi"},
    {"HF-NS", "C4qpg5UNcik"},
    {"HF-PS", "C9evSnwOioU"},
    {"HF-TAV", "C45wj0zt5Ns"}
  ]

  # Posts cadastrados no passo ERRADO: realocar para o certo.
  # {shortcode, passo_certo, passo_errado_atual}
  @move [
    {"DOO9okqDQlE", "HF-B2TA", "HF-CAB"},
    {"DIZDH61NqLV", "HF-STD", "HF-AWK"},
    {"C6hEm8uhYgu", "HF-ALC", "HF-PS"},
    {"C4_dEkINIjg", "HF-CCS", "SCxX"}
  ]

  def up do
    Enum.each(@insert, fn {code, shortcode} -> insert_link(code, shortcode) end)
    Enum.each(@move, fn {shortcode, to_code, _from} -> move_link(shortcode, to_code) end)
  end

  def down do
    Enum.each(@move, fn {shortcode, _to, from_code} -> move_link(shortcode, from_code) end)
    Enum.each(@insert, fn {code, shortcode} -> delete_link(code, shortcode) end)
  end

  defp insert_link(code, shortcode) do
    execute("""
    INSERT INTO step_links (id, url, title, approved, step_id, submitted_by_id, inserted_at, updated_at)
    SELECT gen_random_uuid(),
           'https://www.instagram.com/p/#{shortcode}/',
           NULL,
           true,
           s.id,
           (SELECT sl.submitted_by_id
              FROM step_links sl
              JOIN steps owner ON owner.id = sl.step_id
             WHERE owner.code LIKE 'HF-%' AND sl.deleted_at IS NULL
             LIMIT 1),
           now(),
           now()
      FROM steps s
     WHERE s.code = '#{code}'
       AND s.deleted_at IS NULL
       AND NOT EXISTS (
         SELECT 1 FROM step_links sl
          WHERE sl.step_id = s.id
            AND strpos(sl.url, '#{shortcode}') > 0
            AND sl.deleted_at IS NULL
       )
    """)
  end

  defp move_link(shortcode, to_code) do
    execute("""
    UPDATE step_links
       SET step_id = (SELECT id FROM steps WHERE code = '#{to_code}'),
           updated_at = now()
     WHERE strpos(url, '#{shortcode}') > 0
       AND deleted_at IS NULL
    """)
  end

  defp delete_link(code, shortcode) do
    execute("""
    DELETE FROM step_links
     WHERE strpos(url, '#{shortcode}') > 0
       AND step_id = (SELECT id FROM steps WHERE code = '#{code}')
    """)
  end
end
