defmodule OGrupoDeEstudos.Study.ActiveDayQuery do
  @moduledoc "Query module for study `ActiveDay`."

  import Ecto.Query

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Study.ActiveDay

  @doc "MapSet of days the user was active within the inclusive range."
  @spec days_between(Ecto.UUID.t(), Date.t(), Date.t()) :: MapSet.t()
  def days_between(user_id, from_date, to_date) do
    from(a in ActiveDay,
      where: a.user_id == ^user_id and a.day >= ^from_date and a.day <= ^to_date,
      select: a.day
    )
    |> Repo.all()
    |> MapSet.new()
  end
end
