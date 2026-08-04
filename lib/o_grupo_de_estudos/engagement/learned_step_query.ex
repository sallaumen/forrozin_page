defmodule OGrupoDeEstudos.Engagement.LearnedStepQuery do
  @moduledoc """
  Query module for the `LearnedStep` schema. Every "learned" read and delete in
  the Engagement context goes through here (project rule: queries in `*Query`).

  This module only touches its own table; resolving the steps (and filtering out
  soft-deleted ones) happens in `Learnings` through the Encyclopedia public API.
  """

  import Ecto.Query

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

  @doc "Step ids learned by the user, most recently learned first."
  @spec step_ids_desc(Ecto.UUID.t()) :: [Ecto.UUID.t()]
  def step_ids_desc(user_id) do
    from(l in LearnedStep,
      where: l.user_id == ^user_id,
      order_by: [desc: l.inserted_at],
      select: l.step_id
    )
    |> Repo.all()
  end
end
