defmodule OGrupoDeEstudosWeb.UserSessionController do
  @moduledoc false

  use OGrupoDeEstudosWeb, :controller

  alias OGrupoDeEstudos.Accounts
  alias OGrupoDeEstudos.Engagement.UserAccessTracking
  alias OGrupoDeEstudos.Study
  alias OGrupoDeEstudosWeb.Tracking.ClientInfo
  alias OGrupoDeEstudosWeb.UserAuth

  def new(conn, params) do
    render(conn, :new,
      error: nil,
      teacher_invite: params["teacher_invite"],
      return_to: params["return_to"]
    )
  end

  def create(
        conn,
        %{
          "session" =>
            %{
              "username" => username,
              "password" => password
            } = session_params
        }
      ) do
    case Accounts.check_credentials(username, password) do
      {:ok, user} ->
        maybe_accept_teacher_invite(user, session_params["teacher_invite"])
        UserAccessTracking.track_login(user, ClientInfo.from_conn(conn), :password)
        redirect_to = session_params["return_to"] || ~p"/collection"

        conn
        |> UserAuth.login(user)
        |> put_flash(:info, "Bem-vindo, #{user.username}!")
        |> redirect(to: redirect_to)

      {:error, :invalid_credentials} ->
        render(conn, :new,
          error: "Nome de usuário ou senha inválidos.",
          teacher_invite: session_params["teacher_invite"],
          return_to: session_params["return_to"]
        )
    end
  end

  def auto_login(conn, %{"token" => token}) do
    case Phoenix.Token.verify(OGrupoDeEstudosWeb.Endpoint, "auto_login", token, max_age: 60) do
      {:ok, user_id} ->
        case Accounts.get_user_by_id(user_id) do
          nil ->
            conn |> redirect(to: ~p"/login")

          user ->
            UserAccessTracking.track_login(user, ClientInfo.from_conn(conn), :auto_login)

            conn
            |> UserAuth.login(user)
            |> redirect(to: ~p"/collection")
        end

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Link de acesso expirado ou inválido.")
        |> redirect(to: ~p"/login")
    end
  end

  def delete(conn, _params) do
    conn
    |> UserAuth.logout()
    |> put_flash(:info, "Sessão encerrada.")
    |> redirect(to: ~p"/login")
  end

  defp maybe_accept_teacher_invite(_user, nil), do: :ok
  defp maybe_accept_teacher_invite(_user, ""), do: :ok

  defp maybe_accept_teacher_invite(user, teacher_invite_slug) do
    case Study.accept_invite(user, teacher_invite_slug) do
      {:ok, _link} -> :ok
      _ -> :ok
    end
  end
end
