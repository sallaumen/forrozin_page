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
end
