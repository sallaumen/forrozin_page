defmodule OGrupoDeEstudosWeb.GoogleAuthController do
  @moduledoc false

  use OGrupoDeEstudosWeb, :controller

  alias OGrupoDeEstudos.Accounts
  alias OGrupoDeEstudos.Accounts.GoogleAuth
  alias OGrupoDeEstudos.Engagement.UserAccessTracking
  alias OGrupoDeEstudos.Study
  alias OGrupoDeEstudosWeb.ReturnTo
  alias OGrupoDeEstudosWeb.Tracking.ClientInfo
  alias OGrupoDeEstudosWeb.UserAuth

  def request(conn, params) do
    case GoogleAuth.authorize_url() do
      {:ok, %{url: url, session_params: session_params}} ->
        conn
        |> put_session(:google_auth_session_params, session_params)
        |> put_session(:google_auth_teacher_invite, params["teacher_invite"])
        |> put_session(:google_auth_return_to, ReturnTo.safe_path(params["return_to"]))
        |> redirect(external: url)

      {:error, _error} ->
        conn
        |> put_flash(:error, "Não foi possível iniciar o login com o Google. Tente de novo.")
        |> redirect(to: ~p"/login")
    end
  end

  def callback(conn, params) do
    with %{} = session_params <- get_session(conn, :google_auth_session_params),
         {:ok, profile} <- GoogleAuth.callback(params, session_params),
         {:ok, user, status} <- Accounts.login_or_register_google_user(profile) do
      complete_login(conn, user, status)
    else
      _error ->
        conn
        |> put_flash(:error, "Não foi possível entrar com o Google. Tente de novo.")
        |> redirect(to: ~p"/login")
    end
  end

  defp complete_login(conn, user, status) do
    maybe_accept_teacher_invite(user, get_session(conn, :google_auth_teacher_invite))
    UserAccessTracking.track_login(user, ClientInfo.from_conn(conn), :google)
    return_to = get_session(conn, :google_auth_return_to)

    conn
    |> UserAuth.login(user)
    |> put_flash(:info, welcome_message(status, user))
    |> redirect(to: ReturnTo.safe_path(return_to, destination(status)))
  end

  defp welcome_message(:registered, user) do
    "Bem-vindo, #{Accounts.first_name(user)}! Sua conta foi criada com o Google. " <>
      "Complete seu perfil quando puder."
  end

  defp welcome_message(:linked, user) do
    "Conta Google conectada! Bem-vindo de volta, #{Accounts.first_name(user)}."
  end

  defp welcome_message(:existing, user), do: "Bem-vindo, #{user.username}!"

  defp destination(:registered), do: ~p"/settings"
  defp destination(_status), do: ~p"/collection"

  defp maybe_accept_teacher_invite(_user, nil), do: :ok
  defp maybe_accept_teacher_invite(_user, ""), do: :ok

  defp maybe_accept_teacher_invite(user, teacher_invite_slug) do
    case Study.accept_invite(user, teacher_invite_slug) do
      {:ok, _link} -> :ok
      _ -> :ok
    end
  end
end
