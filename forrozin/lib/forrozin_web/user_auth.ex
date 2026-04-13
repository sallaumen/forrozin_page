defmodule ForrozinWeb.UserAuth do
  @moduledoc """
  Plug e on_mount hook para autenticação de usuários.

  - `fetch_current_user/2` — popula `conn.assigns.current_user` a partir da sessão.
  - `require_authenticated_user/2` — redireciona para /entrar se não autenticado.
  - `redirect_if_authenticated/2` — redireciona para / se já autenticado.
  - `on_mount/4` — variantes acima para uso em LiveViews.
  """

  use ForrozinWeb, :verified_routes

  import Phoenix.Controller
  import Plug.Conn

  alias Forrozin.Accounts
  alias Phoenix.LiveView

  # ---------------------------------------------------------------------------
  # Plug behaviour (suporte ao uso no pipeline: plug ForrozinWeb.UserAuth, :fn)
  # ---------------------------------------------------------------------------

  def init(fun), do: fun
  def call(conn, fun), do: apply(__MODULE__, fun, [conn, []])

  # ---------------------------------------------------------------------------
  # Plugs
  # ---------------------------------------------------------------------------

  @doc "Busca o usuário atual na sessão e atribui em `conn.assigns.current_user`."
  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)

    user =
      if user_id do
        Accounts.buscar_usuario_por_id(user_id)
      end

    assign(conn, :current_user, user)
  end

  @doc "Redireciona para /entrar se o usuário não estiver autenticado."
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "Você precisa estar autenticado para acessar esta página.")
      |> redirect(to: ~p"/entrar")
      |> halt()
    end
  end

  @doc "Redireciona para / se o usuário já estiver autenticado."
  def redirect_if_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: ~p"/acervo")
      |> halt()
    else
      conn
    end
  end

  # ---------------------------------------------------------------------------
  # on_mount para LiveViews
  # ---------------------------------------------------------------------------

  @doc """
  Hook `on_mount` para LiveViews.

  - `:mount_current_user` — popula `current_user` no socket, sem redirecionar.
  - `:ensure_authenticated` — redireciona para /entrar se não autenticado.
  - `:redirect_if_authenticated` — redireciona para / se já autenticado.
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
        |> LiveView.redirect(to: ~p"/entrar")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_user do
      {:halt, LiveView.redirect(socket, to: ~p"/acervo")}
    else
      {:cont, socket}
    end
  end

  defp mount_current_user(session, socket) do
    user =
      case session["user_id"] do
        nil -> nil
        id -> Accounts.buscar_usuario_por_id(id)
      end

    Phoenix.Component.assign(socket, current_user: user)
  end

  # ---------------------------------------------------------------------------
  # Helpers de sessão
  # ---------------------------------------------------------------------------

  @doc "Inicia a sessão do usuário após login bem-sucedido."
  def login(conn, user) do
    conn
    |> renew_session()
    |> put_session(:user_id, user.id)
    |> put_session(:live_socket_id, "users_sessions:#{user.id}")
  end

  @doc "Encerra a sessão do usuário."
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
