defmodule Forrozin.Repo.Migrations.RenameColumnsToEnglish do
  use Ecto.Migration

  def up do
    # ── passos ────────────────────────────────────────────────────
    rename table(:passos), :codigo, to: :code
    rename table(:passos), :nome, to: :name
    rename table(:passos), :nota, to: :note
    rename table(:passos), :caminho_imagem, to: :image_path
    rename table(:passos), :posicao, to: :position
    rename table(:passos), :categoria_id, to: :category_id
    rename table(:passos), :secao_id, to: :section_id
    rename table(:passos), :subsecao_id, to: :subsection_id

    execute "UPDATE passos SET status = 'published' WHERE status = 'publicado'"
    execute "UPDATE passos SET status = 'draft'     WHERE status = 'rascunho'"

    # ── categorias ────────────────────────────────────────────────
    rename table(:categorias), :nome, to: :name
    rename table(:categorias), :rotulo, to: :label
    rename table(:categorias), :cor, to: :color

    # ── secoes ────────────────────────────────────────────────────
    rename table(:secoes), :titulo, to: :title
    rename table(:secoes), :codigo, to: :code
    rename table(:secoes), :descricao, to: :description
    rename table(:secoes), :nota, to: :note
    rename table(:secoes), :posicao, to: :position
    rename table(:secoes), :categoria_id, to: :category_id

    # ── subsecoes ─────────────────────────────────────────────────
    rename table(:subsecoes), :titulo, to: :title
    rename table(:subsecoes), :nota, to: :note
    rename table(:subsecoes), :posicao, to: :position
    rename table(:subsecoes), :secao_id, to: :section_id

    # ── conexoes_passos ───────────────────────────────────────────
    rename table(:conexoes_passos), :tipo, to: :type
    rename table(:conexoes_passos), :rotulo, to: :label
    rename table(:conexoes_passos), :descricao, to: :description
    rename table(:conexoes_passos), :passo_origem_id, to: :source_step_id
    rename table(:conexoes_passos), :passo_destino_id, to: :target_step_id

    execute "UPDATE conexoes_passos SET type = 'exit'  WHERE type = 'saida'"
    execute "UPDATE conexoes_passos SET type = 'entry' WHERE type = 'entrada'"

    # ── conceitos_tecnicos ────────────────────────────────────────
    rename table(:conceitos_tecnicos), :titulo, to: :title
    rename table(:conceitos_tecnicos), :descricao, to: :description

    # ── usuarios ──────────────────────────────────────────────────
    rename table(:usuarios), :nome_usuario, to: :username
    rename table(:usuarios), :senha_hash, to: :password_hash
    rename table(:usuarios), :papel, to: :role

    # ── rename unique indexes so Ecto constraint checks still work ─
    execute "ALTER INDEX IF EXISTS passos_codigo_index
               RENAME TO passos_code_index"
    execute "ALTER INDEX IF EXISTS categorias_nome_index
               RENAME TO categorias_name_index"
    execute "ALTER INDEX IF EXISTS usuarios_nome_usuario_index
               RENAME TO usuarios_username_index"

    execute """
    ALTER INDEX IF EXISTS
      conexoes_passos_passo_origem_id_passo_destino_id_tipo_index
    RENAME TO
      conexoes_passos_source_step_id_target_step_id_type_index
    """
  end

  def down do
    raise "Irreversível — restaurar a partir do backup backup_20260413_211128.json"
  end
end
