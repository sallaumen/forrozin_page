defmodule OGrupoDeEstudos.Repo.Migrations.CreateWorkshopTeachers do
  use Ecto.Migration

  # Quem organiza e quem da a aula eram a mesma pessoa por acidente: o
  # formulario nao tinha campo de professor nenhum, e o criador virava
  # professor por omissao. Isso quebra no caso real de alguem organizar a aula
  # de outra pessoa.
  #
  # `user_id` OU `display_name`: professor de fora nem sempre tem conta, e
  # esperar a conta existir para poder divulgar a aula seria travar o mundo
  # real por causa do banco. Quando a conta aparecer, quem organiza troca o
  # nome pela conta e o que ja foi divulgado nao muda de lugar.
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
    # A mesma conta nao entra duas vezes; nome escrito nao tem como conferir.
    create unique_index(:workshop_teachers, [:workshop_id, :user_id],
             where: "user_id IS NOT NULL",
             name: :workshop_teachers_conta_unica_index
           )

    create constraint(:workshop_teachers, :conta_ou_nome,
             check: "(user_id IS NOT NULL) <> (display_name IS NOT NULL)"
           )
  end
end
