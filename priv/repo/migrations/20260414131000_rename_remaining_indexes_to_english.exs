defmodule Forrozin.Repo.Migrations.RenameRemainingIndexesToEnglish do
  use Ecto.Migration

  def up do
    # Primary keys
    execute "ALTER INDEX IF EXISTS passos_pkey RENAME TO steps_pkey"
    execute "ALTER INDEX IF EXISTS categorias_pkey RENAME TO categories_pkey"
    execute "ALTER INDEX IF EXISTS secoes_pkey RENAME TO sections_pkey"
    execute "ALTER INDEX IF EXISTS subsecoes_pkey RENAME TO subsections_pkey"
    execute "ALTER INDEX IF EXISTS conexoes_passos_pkey RENAME TO step_connections_pkey"
    execute "ALTER INDEX IF EXISTS conceitos_tecnicos_pkey RENAME TO technical_concepts_pkey"
    execute "ALTER INDEX IF EXISTS usuarios_pkey RENAME TO users_pkey"

    # Users indexes
    execute "ALTER INDEX IF EXISTS usuarios_email_index RENAME TO users_email_index"

    execute "ALTER INDEX IF EXISTS usuarios_confirmation_token_index RENAME TO users_confirmation_token_index"

    # Steps indexes
    execute "ALTER INDEX IF EXISTS passos_categoria_id_index RENAME TO steps_category_id_index"
    execute "ALTER INDEX IF EXISTS passos_secao_id_index RENAME TO steps_section_id_index"
    execute "ALTER INDEX IF EXISTS passos_subsecao_id_index RENAME TO steps_subsection_id_index"
    execute "ALTER INDEX IF EXISTS passos_wip_index RENAME TO steps_wip_index"
    execute "ALTER INDEX IF EXISTS passos_status_index RENAME TO steps_status_index"

    # Sections indexes
    execute "ALTER INDEX IF EXISTS secoes_categoria_id_index RENAME TO sections_category_id_index"
    execute "ALTER INDEX IF EXISTS secoes_posicao_index RENAME TO sections_position_index"

    # Subsections indexes
    execute "ALTER INDEX IF EXISTS subsecoes_secao_id_index RENAME TO subsections_section_id_index"
    execute "ALTER INDEX IF EXISTS subsecoes_posicao_index RENAME TO subsections_position_index"

    # Step connections indexes
    execute "ALTER INDEX IF EXISTS conexoes_passos_passo_origem_id_index RENAME TO step_connections_source_step_id_index"

    execute "ALTER INDEX IF EXISTS conexoes_passos_passo_destino_id_index RENAME TO step_connections_target_step_id_index"

    # Technical concepts indexes
    execute "ALTER INDEX IF EXISTS conceitos_tecnicos_titulo_index RENAME TO technical_concepts_title_index"
  end

  def down do
    raise "Irreversible — restore from backup"
  end
end
