defmodule OGrupoDeEstudosWeb.Plugs.TrackDailyActivity do
  @moduledoc """
  Registra que o usuário logado esteve ativo hoje (ao abrir qualquer página),
  no máximo uma vez por sessão por dia. Alimenta a consistência da área de
  Estudos: o dia conta mesmo sem registro de diário.
  """
  import Plug.Conn

  alias OGrupoDeEstudos.Study

  def init(opts), do: opts

  def call(%{assigns: %{current_user: %{id: user_id}}} = conn, _opts) do
    today_iso = OGrupoDeEstudos.Brazil.today() |> Date.to_iso8601()

    if get_session(conn, :active_day) == today_iso do
      conn
    else
      Study.record_active_day(user_id, OGrupoDeEstudos.Brazil.today())
      put_session(conn, :active_day, today_iso)
    end
  end

  def call(conn, _opts), do: conn
end
