defmodule OGrupoDeEstudosWeb.UserRegistrationLive do
  @moduledoc false

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.Accounts

  on_mount {OGrupoDeEstudosWeb.UserAuth, :redirect_if_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Cadastro", form: to_form(%{}, as: :user))}
  end

  @impl true
  def handle_event("register", %{"user" => params}, socket) do
    case Accounts.register_user(params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Bem-vindo ao Forrózin, #{user.username}!")
         |> redirect(to: ~p"/auto-login/#{user.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :user))}
    end
  end
end
