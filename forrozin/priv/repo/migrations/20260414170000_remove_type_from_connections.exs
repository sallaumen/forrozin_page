defmodule Forrozin.Repo.Migrations.RemoveTypeFromConnections do
  use Ecto.Migration

  def up do
    alter table(:step_connections) do
      remove :type
    end

    # Drop old unique index that included type
    execute "DROP INDEX IF EXISTS step_connections_source_step_id_target_step_id_type_index"

    # Create new unique index without type
    create unique_index(:step_connections, [:source_step_id, :target_step_id],
             name: :step_connections_source_target_index
           )
  end

  def down do
    drop_if_exists index(:step_connections, [:source_step_id, :target_step_id],
                     name: :step_connections_source_target_index
                   )

    alter table(:step_connections) do
      add :type, :string, default: "exit"
    end

    create unique_index(:step_connections, [:source_step_id, :target_step_id, :type],
             name: :step_connections_source_step_id_target_step_id_type_index
           )
  end
end
