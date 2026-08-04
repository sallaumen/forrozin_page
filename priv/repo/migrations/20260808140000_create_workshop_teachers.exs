defmodule OGrupoDeEstudos.Repo.Migrations.CreateWorkshopTeachers do
  use Ecto.Migration

  # Organizing and teaching were the same person by accident: the form had no
  # teacher field at all, and the creator became a teacher by omission. That breaks
  # in the real case of someone organizing another person's class.
  #
  # `user_id` OR `display_name`: a visiting teacher does not always have an account,
  # and waiting for the account to exist before announcing the class would hold up
  # the real world for the database. When the account appears, the organizer swaps
  # the name for it and what was already announced does not move.
  def change do
    create table(:workshop_teachers, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :workshop_id, references(:workshops, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :display_name, :string
      add :position, :integer, null: false, default: 1

      timestamps(type: :utc_datetime_usec)
    end

    create index(:workshop_teachers, [:workshop_id, :position])
    # The same account does not go in twice; a written name cannot be checked.
    create unique_index(:workshop_teachers, [:workshop_id, :user_id],
             where: "user_id IS NOT NULL",
             name: :workshop_teachers_conta_unica_index
           )

    create constraint(:workshop_teachers, :conta_ou_nome,
             check: "(user_id IS NOT NULL) <> (display_name IS NOT NULL)"
           )
  end
end
