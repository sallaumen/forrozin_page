defmodule OGrupoDeEstudosWeb.Tracking.ClientInfo do
  @moduledoc """
  Extracts lightweight client metadata from browser requests.
  """

  import Plug.Conn

  def from_conn(conn) do
    ua = conn |> get_req_header("user-agent") |> List.first() || ""

    %{
      device_type: detect_device_type(ua),
      browser: detect_browser(ua),
      is_pwa: detect_pwa(conn),
      user_agent: String.slice(ua, 0, 500)
    }
  end

  def detect_device_type(ua) do
    ua_lower = String.downcase(ua || "")

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

  def detect_browser(ua) do
    ua_lower = String.downcase(ua || "")

    cond do
      String.contains?(ua_lower, "edg/") -> "Edge"
      String.contains?(ua_lower, "opr/") or String.contains?(ua_lower, "opera") -> "Opera"
      String.contains?(ua_lower, "chrome") -> "Chrome"
      String.contains?(ua_lower, "safari") -> "Safari"
      String.contains?(ua_lower, "firefox") -> "Firefox"
      true -> "Other"
    end
  end

  # PWA standalone mode cannot be reliably detected server-side.
  # This mirrors the existing weak heuristic used for device sessions.
  def detect_pwa(conn) do
    fetch_site = conn |> get_req_header("sec-fetch-site") |> List.first()
    fetch_mode = conn |> get_req_header("sec-fetch-mode") |> List.first()

    fetch_site == "none" and fetch_mode == "navigate"
  end
end
