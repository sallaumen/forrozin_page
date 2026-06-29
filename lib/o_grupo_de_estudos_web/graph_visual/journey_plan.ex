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

  @doc """
  Frase + textinho de incentivo conforme o número de passos aprendidos. Muda a
  cada 10 passos (até 60+). Sempre elogia e fala do caminho à frente, nunca do
  quanto falta. Retorna `{frase, textinho}`.
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
