defmodule OGrupoDeEstudos.Repo.Migrations.CreateLessonSteps do
  use Ecto.Migration

  # A nota do diario vincula passo desde sempre (`study_note_steps`). A licao,
  # que e o material mais deliberado que o professor produz, nascia so com
  # titulo e conteudo: escrever "trabalhamos inversao hoje" nao levava a lugar
  # nenhum. Mesmo molde da nota, para o aluno reencontrar o passo no acervo.
  def change do
    create table(:lesson_steps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :lesson_id, references(:lessons, type: :binary_id, on_delete: :delete_all), null: false
      add :step_id, references(:steps, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:lesson_steps, [:lesson_id, :step_id])
    # Le-se sempre por licao, em lote, para a lista de licoes nao virar N+1.
    create index(:lesson_steps, [:lesson_id])
    # E o caminho de volta: "onde eu vi este passo?"
    create index(:lesson_steps, [:step_id])
  end
end
