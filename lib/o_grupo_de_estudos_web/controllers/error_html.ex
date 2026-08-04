defmodule OGrupoDeEstudosWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use OGrupoDeEstudosWeb, :html

  # Renders a plain text page from the template name: "404.html" becomes "Not Found".
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
