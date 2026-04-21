defmodule OGrupoDeEstudos.Repo.Migrations.AddStudyAreaFieldsAndTables do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_teacher, :boolean, default: false, null: false
      add :invite_slug, :string
    end

    execute("UPDATE users SET invite_slug = 'prof-' || username WHERE invite_slug IS NULL")

    alter table(:users) do
      modify :invite_slug, :string, null: false
    end

    create unique_index(:users, [:invite_slug])

    create table(:teacher_student_links, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :teacher_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :student_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :active, :boolean, default: true, null: false
      add :ended_at, :utc_datetime_usec

      timestamps()
    end

    create unique_index(:teacher_student_links, [:teacher_id, :student_id])

    create table(:study_notes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :kind, :string, null: false
      add :note_date, :date, null: false
      add :content, :text, null: false, default: ""
      add :owner_user_id, references(:users, type: :binary_id, on_delete: :delete_all)

      add :teacher_student_link_id,
          references(:teacher_student_links,
            type: :binary_id,
            on_delete: :delete_all
          )

      timestamps()
    end

    create unique_index(:study_notes, [:owner_user_id, :note_date],
             where: "kind = 'personal'",
             name: :study_notes_personal_unique_index
           )

    create unique_index(:study_notes, [:teacher_student_link_id, :note_date],
             where: "kind = 'shared'",
             name: :study_notes_shared_unique_index
           )

    create table(:study_note_steps, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :study_note_id, references(:study_notes, type: :binary_id, on_delete: :delete_all),
        null: false

      add :step_id, references(:steps, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:study_note_steps, [:study_note_id, :step_id])
  end
end
