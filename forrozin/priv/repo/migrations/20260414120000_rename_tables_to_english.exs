defmodule Forrozin.Repo.Migrations.RenameTablesToEnglish do
  use Ecto.Migration

  def up do
    # Rename tables
    execute "ALTER TABLE passos RENAME TO steps"
    execute "ALTER TABLE categorias RENAME TO categories"
    execute "ALTER TABLE secoes RENAME TO sections"
    execute "ALTER TABLE subsecoes RENAME TO subsections"
    execute "ALTER TABLE conexoes_passos RENAME TO step_connections"
    execute "ALTER TABLE conceitos_tecnicos RENAME TO technical_concepts"
    execute "ALTER TABLE conceitos_passos RENAME TO concept_steps"
    execute "ALTER TABLE usuarios RENAME TO users"

    # Rename join table columns
    rename table(:concept_steps), :conceito_id, to: :concept_id
    rename table(:concept_steps), :passo_id, to: :step_id

    # Rename indexes to match new table names
    execute "ALTER INDEX IF EXISTS passos_code_index RENAME TO steps_code_index"
    execute "ALTER INDEX IF EXISTS categorias_name_index RENAME TO categories_name_index"
    execute "ALTER INDEX IF EXISTS usuarios_username_index RENAME TO users_username_index"

    execute "ALTER INDEX IF EXISTS conexoes_passos_source_step_id_target_step_id_type_index RENAME TO step_connections_source_step_id_target_step_id_type_index"

    # Rename FK indexes (Ecto auto-generates these as {table}_{column}_index)
    execute "ALTER INDEX IF EXISTS passos_category_id_index RENAME TO steps_category_id_index"
    execute "ALTER INDEX IF EXISTS passos_section_id_index RENAME TO steps_section_id_index"
    execute "ALTER INDEX IF EXISTS passos_subsection_id_index RENAME TO steps_subsection_id_index"
    execute "ALTER INDEX IF EXISTS secoes_category_id_index RENAME TO sections_category_id_index"

    execute "ALTER INDEX IF EXISTS subsecoes_section_id_index RENAME TO subsections_section_id_index"

    execute "ALTER INDEX IF EXISTS conexoes_passos_source_step_id_index RENAME TO step_connections_source_step_id_index"

    execute "ALTER INDEX IF EXISTS conexoes_passos_target_step_id_index RENAME TO step_connections_target_step_id_index"

    execute "ALTER INDEX IF EXISTS conceitos_passos_conceito_id_passo_id_index RENAME TO concept_steps_concept_id_step_id_index"
  end

  def down do
    raise "Irreversible — restore from backup"
  end
end
