defmodule OGrupoDeEstudosWeb.UserAuth do
  @moduledoc """
  Plug and on_mount hook for user authentication.

  - `fetch_current_user/2` populates `conn.assigns.current_user` from the session.
  - `require_authenticated_user/2` redirects to the login page when there is none.
  - `on_mount/4` does the same for LiveViews.
  """

  use OGrupoDeEstudosWeb, :verified_routes

  import Phoenix.Controller
  import Plug.Conn

  alias OGrupoDeEstudos.Accounts
  alias Phoenix.LiveView

  def init(fun), do: fun
  def call(conn, fun), do: apply(__MODULE__, fun, [conn, []])

  @doc "Fetches the current user from the session into `conn.assigns.current_user`."
  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)

    user =
      if user_id do
        Accounts.get_user_by_id(user_id)
      end

    assign(conn, :current_user, user)
  end

  @doc "Redirects to the login page when the user is not authenticated."
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "Você precisa estar autenticado para acessar esta página.")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  @doc """
  Conn plug for admin routes (controllers and live_dashboard, where the
  `:ensure_admin` on_mount does not apply). A non-admin goes back to the map; an
  anonymous visitor goes to login.
  """
  def require_admin(conn, _opts) do
    case conn.assigns[:current_user] do
      %{role: :admin} ->
        conn

      nil ->
        conn
        |> put_flash(:error, "Você precisa estar autenticado para acessar esta página.")
        |> redirect(to: ~p"/login")
        |> halt()

      _user ->
        conn
        |> redirect(to: ~p"/graph/visual")
        |> halt()
    end
  end

  @doc "Redirects to / when the user is already authenticated."
  def redirect_if_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: ~p"/collection")
      |> halt()
    else
      conn
    end
  end

  @doc """
  `on_mount` hook for LiveViews.

  - `:mount_current_user` populates `current_user` in the socket, without redirecting.
  - `:ensure_authenticated` redirects to login when there is no user.
  - `:ensure_admin` redirects when the user is not an admin.
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(session, socket)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> LiveView.put_flash(:error, "Você precisa estar autenticado para acessar esta página.")
        |> LiveView.redirect(to: ~p"/login")

      {:halt, socket}
    end
  end

  def on_mount(:ensure_admin, _params, session, socket) do
    socket = mount_current_user(session, socket)

    cond do
      is_nil(socket.assigns.current_user) ->
        socket =
          socket
          |> LiveView.put_flash(
            :error,
            "Você precisa estar autenticado para acessar esta página."
          )
          |> LiveView.redirect(to: ~p"/login")

        {:halt, socket}

      Accounts.admin?(socket.assigns.current_user) ->
        {:cont, socket}

      true ->
        {:halt, LiveView.redirect(socket, to: ~p"/graph/visual")}
    end
  end

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_user do
      {:halt, LiveView.redirect(socket, to: ~p"/collection")}
    else
      {:cont, socket}
    end
  end

  defp mount_current_user(session, socket) do
    user =
      case session["user_id"] do
        nil -> nil
        id -> Accounts.get_user_by_id(id)
      end

    Phoenix.Component.assign(socket, current_user: user)
  end

  @doc "Starts the user session after a successful login."
  def login(conn, user) do
    conn
    |> renew_session()
    |> put_session(:user_id, user.id)
    |> put_session(:live_socket_id, "users_sessions:#{user.id}")
  end

  @doc "Ends the user session."
  def logout(conn) do
    conn
    |> renew_session()
    |> delete_session(:user_id)
  end

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
