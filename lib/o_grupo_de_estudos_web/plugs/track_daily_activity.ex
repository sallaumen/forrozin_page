defmodule OGrupoDeEstudosWeb.Plugs.TrackDailyActivity do
  @moduledoc """
  Records that the logged-in user was active today (on opening any page), at most
  once per session per day. Feeds the consistency count of the Study area.
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
