defmodule OGrupoDeEstudos.Repo.Migrations.AddTeacherStudentLinksStudentIndex do
  use Ecto.Migration

  # Index build with no write lock on the table (concurrently has to run outside
  # a DDL transaction).
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    create_if_not_exists index(:teacher_student_links, [:student_id],
                           name: :teacher_student_links_student_id_index,
                           concurrently: true
                         )
  end

  def down do
    drop_if_exists index(:teacher_student_links, [:student_id],
                     name: :teacher_student_links_student_id_index
                   )
  end
end
