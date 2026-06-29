defmodule OGrupoDeEstudosWeb.GraphVisual.JourneyPlan do
  @moduledoc """
  Plano-base de estudos: a sequência pedagógica dos primeiros passos (ordem
  definida pelo professor). É a "próxima meta" enquanto o aluno não dominou
  esses passos; depois, a recomendação passa a ser automática.

  Por ora é uma constante; a fase de recomendação automática torna isto editável
  por admin (mantendo este módulo como o default/seed).
  """

  alias OGrupoDeEstudosWeb.GraphVisual.StudyJourney

  @base_plan ~w(BF BAL BA GS-ME GS-CHO BL GP PI SC CA-F TR-FC IV)

  @doc "Códigos do plano-base, em ordem pedagógica."
  @spec base_plan() :: [String.t()]
  def base_plan, do: @base_plan

  @doc "Próxima meta: primeiro passo do plano-base ainda não aprendido (ou nil)."
  @spec next_goal([String.t()]) :: String.t() | nil
  def next_goal(learned_codes) do
    StudyJourney.next_goal(@base_plan, MapSet.new(learned_codes))
  end

  @doc "Nome do nível da jornada a partir do percentual de progresso (0-100)."
  @spec level(integer()) :: String.t()
  def level(pct) when pct >= 100, do: "Dominou"
  def level(pct) when pct >= 80, do: "Quase lá"
  def level(pct) when pct >= 50, do: "Avançando"
  def level(pct) when pct >= 20, do: "Engrenando"
  def level(pct) when pct >= 1, do: "Pegando o jeito"
  def level(_pct), do: "Começando"
end
