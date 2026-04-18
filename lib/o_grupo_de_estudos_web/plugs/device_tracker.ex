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

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]
    tracked = get_session(conn, :device_tracked)

    if user && !tracked do
      ua = conn |> get_req_header("user-agent") |> List.first() || ""
      attrs = device_session_attrs(conn, user.id, ua)

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

  defp device_session_attrs(conn, user_id, ua) do
    %{
      user_id: user_id,
      device_type: detect_device_type(ua),
      browser: detect_browser(ua),
      is_pwa: detect_pwa(conn),
      user_agent: String.slice(ua, 0, 500)
    }
  end

  defp insert_device_session(attrs) do
    %DeviceSession{}
    |> DeviceSession.changeset(attrs)
    |> Repo.insert()
  end

  defp detect_device_type(ua) do
    ua_lower = String.downcase(ua)

    cond do
      String.contains?(ua_lower, "ipad") or String.contains?(ua_lower, "tablet") ->
        "tablet"

      String.contains?(ua_lower, "mobile") or String.contains?(ua_lower, "android") or
          String.contains?(ua_lower, "iphone") ->
        "mobile"

      true ->
        "desktop"
    end
  end

  defp detect_browser(ua) do
    ua_lower = String.downcase(ua)

    cond do
      String.contains?(ua_lower, "edg/") -> "Edge"
      String.contains?(ua_lower, "opr/") or String.contains?(ua_lower, "opera") -> "Opera"
      # Chrome check must come after Edge/Opera (both include "chrome")
      String.contains?(ua_lower, "chrome") -> "Chrome"
      String.contains?(ua_lower, "safari") -> "Safari"
      String.contains?(ua_lower, "firefox") -> "Firefox"
      true -> "Other"
    end
  end

  # PWA standalone mode cannot be reliably detected server-side.
  # The JS hook sends a push_event to update is_pwa after mount.
  # Here we check the Sec-Fetch-Site header as a weak heuristic:
  # standalone PWAs typically have no referrer and Sec-Fetch-Site: none.
  defp detect_pwa(conn) do
    fetch_site = conn |> get_req_header("sec-fetch-site") |> List.first()
    fetch_mode = conn |> get_req_header("sec-fetch-mode") |> List.first()
    fetch_site == "none" and fetch_mode == "navigate"
  end
end
