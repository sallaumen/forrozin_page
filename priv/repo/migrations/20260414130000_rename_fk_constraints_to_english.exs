defmodule Forrozin.Repo.Migrations.RenameFkConstraintsToEnglish do
  use Ecto.Migration

  def up do
    # steps FK constraints
    execute "ALTER TABLE steps RENAME CONSTRAINT passos_categoria_id_fkey TO steps_category_id_fkey"
    execute "ALTER TABLE steps RENAME CONSTRAINT passos_secao_id_fkey TO steps_section_id_fkey"

    execute "ALTER TABLE steps RENAME CONSTRAINT passos_subsecao_id_fkey TO steps_subsection_id_fkey"

    # sections FK constraints
    execute "ALTER TABLE sections RENAME CONSTRAINT secoes_categoria_id_fkey TO sections_category_id_fkey"

    # subsections FK constraints
    execute "ALTER TABLE subsections RENAME CONSTRAINT subsecoes_secao_id_fkey TO subsections_section_id_fkey"

    # step_connections FK constraints
    execute "ALTER TABLE step_connections RENAME CONSTRAINT conexoes_passos_passo_origem_id_fkey TO step_connections_source_step_id_fkey"

    execute "ALTER TABLE step_connections RENAME CONSTRAINT conexoes_passos_passo_destino_id_fkey TO step_connections_target_step_id_fkey"

    # concept_steps FK constraints
    execute "ALTER TABLE concept_steps RENAME CONSTRAINT conceitos_passos_conceito_id_fkey TO concept_steps_concept_id_fkey"

    execute "ALTER TABLE concept_steps RENAME CONSTRAINT conceitos_passos_passo_id_fkey TO concept_steps_step_id_fkey"
  end

  def down do
    raise "Irreversible — restore from backup"
  end
end
