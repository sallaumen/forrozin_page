defmodule OGrupoDeEstudosWeb.Components.Navbar do
  @moduledoc "Shared navigation bar for all authenticated pages."

  use Phoenix.Component
  use OGrupoDeEstudosWeb, :verified_routes

  attr :current_user, :map, required: true
  attr :is_admin, :boolean, default: false

  def navbar(assigns) do
    ~H"""
    <header style="background: #1a0e05; padding: 12px 24px; display: flex; align-items: center; justify-content: space-between; position: sticky; top: 0; z-index: 200;">
      <.link
        navigate={~p"/collection"}
        style="font-family: Georgia, serif; font-size: 13px; font-weight: 700; letter-spacing: 2px; color: #f2ede4; text-transform: uppercase; text-decoration: none;"
      >
        Forrózin
      </.link>
      <nav style="display: flex; gap: 16px; align-items: center;">
        <.link
          navigate={~p"/collection"}
          style="font-family: Georgia, serif; font-size: 12px; color: #bba88a; text-decoration: none; letter-spacing: 0.5px;"
        >
          Acervo
        </.link>
        <.link
          navigate={~p"/graph/visual"}
          style="font-family: Georgia, serif; font-size: 12px; color: #bba88a; text-decoration: none; letter-spacing: 0.5px;"
        >
          Mapa
        </.link>
        <.link
          navigate={~p"/community"}
          style="font-family: Georgia, serif; font-size: 12px; color: #bba88a; text-decoration: none; letter-spacing: 0.5px;"
        >
          Comunidade
        </.link>
        <%= if @is_admin do %>
          <.link
            navigate={~p"/graph"}
            style="font-family: Georgia, serif; font-size: 11px; color: #9a7a5a; text-decoration: none; letter-spacing: 0.5px;"
          >
            Conexões
          </.link>
          <.link
            navigate={~p"/admin/links"}
            style="font-family: Georgia, serif; font-size: 11px; color: #9a7a5a; text-decoration: none; letter-spacing: 0.5px;"
          >
            Links
          </.link>
          <.link
            navigate={~p"/admin/backups"}
            style="font-family: Georgia, serif; font-size: 11px; color: #9a7a5a; text-decoration: none; letter-spacing: 0.5px;"
          >
            Backups
          </.link>
        <% end %>
        <span style="width: 1px; height: 16px; background: rgba(255,255,255,0.15);"></span>
        <.link
          navigate={~p"/users/#{@current_user.username}"}
          style="font-size: 12px; color: #f2ede4; text-decoration: none; letter-spacing: 0.5px;"
        >
          Olá, <strong>{OGrupoDeEstudos.Accounts.first_name(@current_user)}</strong>
        </.link>
        <.link
          navigate={~p"/settings"}
          style="color: #bba88a; text-decoration: none; font-size: 14px;"
          title="Configurações"
        >
          ⚙
        </.link>
        <form method="post" action={~p"/logout"} style="margin: 0;">
          <input type="hidden" name="_method" value="delete" />
          <input
            type="hidden"
            name="_csrf_token"
            value={Plug.CSRFProtection.get_csrf_token()}
          />
          <button
            type="submit"
            style="font-family: Georgia, serif; font-size: 11px; color: #7a5c3a; background: none; border: none; cursor: pointer;"
          >
            sair
          </button>
        </form>
      </nav>
    </header>
    """
  end
end
