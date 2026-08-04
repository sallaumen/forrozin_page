defmodule OGrupoDeEstudosWeb.UserSessionHTML do
  @moduledoc false

  use OGrupoDeEstudosWeb, :html

  import OGrupoDeEstudosWeb.UI.GoogleSignIn

  embed_templates "user_session_html/*"
end
