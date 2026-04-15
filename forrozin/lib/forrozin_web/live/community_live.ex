defmodule ForrozinWeb.CommunityLive do
  @moduledoc """
  Community page — shows all suggested steps with rich cards.

  Tabs: all | pending | approved.
  Accessible to all authenticated users.
  """

  use ForrozinWeb, :live_view

  alias Forrozin.{Accounts, Encyclopedia}

  on_mount {ForrozinWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    admin = Accounts.admin?(socket.assigns.current_user)
    steps = Encyclopedia.list_suggested_steps_filtered(filter: "all")

    {:ok,
     assign(socket,
       page_title: "Comunidade",
       is_admin: admin,
       active_tab: "all",
       steps: steps
     )}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    steps = Encyclopedia.list_suggested_steps_filtered(filter: tab)
    {:noreply, assign(socket, active_tab: tab, steps: steps)}
  end

  # Helpers

  def category_color(%{category: %{color: color}}), do: color
  def category_color(_), do: "#7f8c8d"

  def category_label(%{category: %{label: label}}), do: label
  def category_label(_), do: ""

  def connection_count(%{connections_as_source: conns_out, connections_as_target: conns_in}) do
    length(conns_out) + length(conns_in)
  end

  def connection_count(_), do: 0
end
