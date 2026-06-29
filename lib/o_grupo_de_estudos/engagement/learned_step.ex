defmodule OGrupoDeEstudos.Engagement.LearnedStep do
  @moduledoc """
  Registro de que um usuário marcou um passo como aprendido (dominado).

  Espelha o padrão de `Favorite`/`Like`, mas é específico de passos (FK real
  para `steps`). Marcar aprendido implica favoritar (ver `Engagement.Learnings`),
  então a estrela de favorito aparece nas demais telas sem duplicar a verdade:
  `favorites` continua sendo a fonte de "é favorito".
  """
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "learned_steps" do
    belongs_to :user, OGrupoDeEstudos.Accounts.User
    belongs_to :step, OGrupoDeEstudos.Encyclopedia.Step
    timestamps(updated_at: false)
  end

  def changeset(learned_step, attrs) do
    learned_step
    |> cast(attrs, [:user_id, :step_id])
    |> validate_required([:user_id, :step_id])
    |> unique_constraint([:user_id, :step_id])
  end
end
