defmodule OGrupoDeEstudosWeb.Plugs.DeviceTracker do
  @moduledoc """
  Logs device information once per browser session for authenticated users.

  Runs after fetch_current_user. Stores a :device_tracked flag in the session
  to avoid re-inserting on every request. Uses Task.start/1 by default so it
  never blocks the response pipeline.
  """

  import Plug.Conn

  alias OGrupoDeEstudos.Repo
  alias OGrupoDeEstudos.Engagement.DeviceSession
  alias OGrupoDeEstudosWeb.Tracking.ClientInfo

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]
    tracked = get_session(conn, :device_tracked)

    if user && !tracked do
      attrs =
        conn
        |> ClientInfo.from_conn()
        |> Map.put(:user_id, user.id)

      if Application.get_env(:o_grupo_de_estudos, :async_device_tracking, true) do
        Task.start(fn -> insert_device_session(attrs) end)
      else
        insert_device_session(attrs)
      end

      put_session(conn, :device_tracked, true)
    else
      conn
    end
  end

  defp insert_device_session(attrs) do
    %DeviceSession{}
    |> DeviceSession.changeset(attrs)
    |> Repo.insert()
  end
end
