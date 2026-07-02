defmodule OGrupoDeEstudos.Engagement.Learnings do
  @moduledoc """
  Passos aprendidos (jornada de estudos). Marcar um passo como aprendido
  registra o progresso E garante o favorito (que por sua vez garante o like),
  então a estrela aparece nas demais telas. Desaprender preserva o favorito.

  Reaproveita a implicação favorito⇒like de `Favorites`; a fonte de verdade de
  "é favorito" continua em `favorites`, sem duplicação.
  """

  alias Ecto.Multi
  alias OGrupoDeEstudos.Encyclopedia
  alias OGrupoDeEstudos.Engagement.{Favorites, LearnedStep, LearnedStepQuery}
  alias OGrupoDeEstudos.Repo

  @doc "Marca/desmarca um passo como aprendido. Retorna `{:ok, :learned | :unlearned}`."
  def toggle_learned(user_id, step_id) do
    if LearnedStepQuery.exists?(user_id, step_id) do
      # delete idempotente por chave: nunca levanta StaleEntryError sob corrida.
      LearnedStepQuery.delete(user_id, step_id)
      {:ok, :unlearned}
    else
      mark_learned(user_id, step_id)
    end
  end

  defp mark_learned(user_id, step_id) do
    Multi.new()
    |> Multi.insert(
      :learned,
      LearnedStep.changeset(%LearnedStep{}, %{user_id: user_id, step_id: step_id})
    )
    |> Multi.run(:favorite, fn _repo, _changes ->
      Favorites.ensure_favorited(user_id, "step", step_id)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} -> {:ok, :learned}
      {:error, _step, changeset, _} -> {:error, changeset}
    end
  end

  @doc "Returns `true` if the user has marked the step as learned."
  def learned?(user_id, step_id), do: LearnedStepQuery.exists?(user_id, step_id)

  @doc "Returns the list of step codes the user has learned (deleted excluded)."
  def learned_step_codes(user_id) do
    user_id
    |> learned_summaries()
    |> Enum.map(& &1.code)
  end

  @doc "Returns the learned Step records, most recently learned first (deleted excluded)."
  def list_learned_steps(user_id) do
    ids = LearnedStepQuery.step_ids_desc(user_id)
    steps = Encyclopedia.steps_by_ids(ids)

    ids
    |> Enum.map(&steps[&1])
    |> Enum.reject(&is_nil/1)
  end

  @doc "Returns the count of steps the user has learned (deleted excluded)."
  def count_user_learned(user_id) do
    user_id
    |> learned_summaries()
    |> length()
  end

  defp learned_summaries(user_id) do
    user_id
    |> LearnedStepQuery.step_ids_desc()
    |> Encyclopedia.step_summaries_by_ids()
    |> Map.values()
  end

  @doc "Reinicia o progresso: remove TODOS os passos aprendidos do usuário (favoritos ficam)."
  def reset_learned(user_id), do: LearnedStepQuery.delete_all_for_user(user_id)
end
