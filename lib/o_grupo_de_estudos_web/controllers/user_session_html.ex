defmodule OGrupoDeEstudosWeb.UserSessionHTML do
  @moduledoc false

  use OGrupoDeEstudosWeb, :html

  import OGrupoDeEstudosWeb.UI.GoogleSignIn

  embed_templates "user_session_html/*"

  @doc "Signup link that keeps the invite and the post-login destination."
  def signup_path(teacher_invite, return_to) do
    params =
      [teacher_invite: teacher_invite, return_to: return_to]
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)

    case params do
      [] -> ~p"/signup"
      params -> ~p"/signup?#{params}"
    end
  end
end
