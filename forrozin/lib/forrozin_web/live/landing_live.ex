defmodule ForrozinWeb.LandingLive do
  @moduledoc "Página inicial pública do Forrózin."

  use ForrozinWeb, :live_view

  alias Forrozin.Enciclopedia

  on_mount {ForrozinWeb.UserAuth, :mount_current_user}

  @impl true
  def mount(_params, _session, socket) do
    total = Enciclopedia.contar_passos_publicos()
    {:ok, assign(socket, page_title: "O grupo de estudos", total_passos: total)}
  end
end
