defmodule OGrupoDeEstudosWeb.GraphVisual.JourneyPlan do
  @moduledoc """
  Base study plan: the pedagogical sequence of the first steps (order defined by
  the teacher). It is the "next goal" while the student has not mastered it.
  """

  alias OGrupoDeEstudosWeb.GraphVisual.StudyJourney

  @base_plan ~w(BF BAL BA GS-ME GS-CHO BL GP PI SC CA-F TR-FC IV)

  @doc "Codes of the base plan, in pedagogical order."
  @spec base_plan() :: [String.t()]
  def base_plan, do: @base_plan

  @doc "Next goal: first step of the base plan not learned yet (or nil)."
  @spec next_goal([String.t()]) :: String.t() | nil
  def next_goal(learned_codes) do
    StudyJourney.next_goal(@base_plan, MapSet.new(learned_codes))
  end

  @doc """
  Headline plus encouragement text according to how many steps are learned. It
  changes every 10 steps (up to 60+). It always praises and speaks of the road
  ahead, never of what is missing.
  """
  @spec encouragement(non_neg_integer()) :: {String.t(), String.t()}
  def encouragement(count) when count >= 60,
    do: {"Voando na pista", "Que baú de passos, hein. O forró nunca acaba de surpreender."}

  def encouragement(count) when count >= 50,
    do: {"Corpo de forrozeiro", "A dança já é tua, e sempre cabe um detalhe novo pra brincar."}

  def encouragement(count) when count >= 40,
    do: {"Rodando o salão", "Os passos já vêm sem você pensar. Bonito demais."}

  def encouragement(count) when count >= 30,
    do: {"Isso já é repertório", "Cada música pede um caminho, e você tem de sobra pra escolher."}

  def encouragement(count) when count >= 20,
    do: {"Olha você dançando!", "Já dá pra inventar bastante coisa quando a música toca."}

  def encouragement(count) when count >= 10,
    do: {"Pegando a manha", "Teu corpo já entende a dança, e tem muito forró pela frente."}

  def encouragement(_count),
    do: {"Começando bonito", "Cada passo novo abre um tanto de caminho na pista."}
end
