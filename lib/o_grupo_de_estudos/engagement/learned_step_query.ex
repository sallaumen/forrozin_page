defmodule OGrupoDeEstudos.Engagement.LearnedStepQuery do
  @moduledoc """
  Query module do schema `LearnedStep`. Toda leitura/remoção de "aprendido" no
  contexto Engagement passa por aqui (regra do projeto: queries em `*Query`).

  As listagens visíveis (códigos, registros e contagem) ignoram passos
  soft-deletados via `visible_for_user/1`, então os três números ficam coerentes
  entre si.
  """

  import Ecto.Query

  alias OGrupoDeEstudos.Encyclopedia.Step
  alias OGrupoDeEstudos.Engagement.LearnedStep
  alias OGrupoDeEstudos.Repo

  @doc "Returns `true` if a learned row exists for the user+step."
  @spec exists?(Ecto.UUID.t(), Ecto.UUID.t()) :: boolean()
  def exists?(user_id, step_id) do
    Repo.exists?(from l in LearnedStep, where: l.user_id == ^user_id and l.step_id == ^step_id)
  end

  @doc "Removes the learned mark for the user+step. Idempotent: returns `{count, nil}`."
  @spec delete(Ecto.UUID.t(), Ecto.UUID.t()) :: {non_neg_integer(), nil}
  def delete(user_id, step_id) do
    from(l in LearnedStep, where: l.user_id == ^user_id and l.step_id == ^step_id)
    |> Repo.delete_all()
  end

  @doc "Removes ALL learned marks for the user (reiniciar progresso). Returns `{count, nil}`."
  @spec delete_all_for_user(Ecto.UUID.t()) :: {non_neg_integer(), nil}
  def delete_all_for_user(user_id) do
    Repo.delete_all(from l in LearnedStep, where: l.user_id == ^user_id)
  end

  @doc "Codes of the user's learned steps (soft-deleted steps excluded)."
  @spec codes_for_user(Ecto.UUID.t()) :: [String.t()]
  def codes_for_user(user_id) do
    user_id |> visible_for_user() |> select([_l, s], s.code) |> Repo.all()
  end

  @doc "Count of the user's learned steps (soft-deleted steps excluded)."
  @spec count(Ecto.UUID.t()) :: non_neg_integer()
  def count(user_id) do
    user_id |> visible_for_user() |> Repo.aggregate(:count)
  end

  @doc "Learned Step records, most recently learned first (soft-deleted excluded)."
  @spec list_steps(Ecto.UUID.t()) :: [Step.t()]
  def list_steps(user_id) do
    user_id
    |> visible_for_user()
    |> order_by([l, _s], desc: l.inserted_at)
    |> select([_l, s], s)
    |> Repo.all()
  end

  defp visible_for_user(user_id) do
    from l in LearnedStep,
      join: s in Step,
      on: s.id == l.step_id,
      where: l.user_id == ^user_id and is_nil(s.deleted_at)
  end
end
