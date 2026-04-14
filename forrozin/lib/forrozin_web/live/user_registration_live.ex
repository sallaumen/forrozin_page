defmodule ForrozinWeb.UserRegistrationLive do
  @moduledoc false

  use ForrozinWeb, :live_view

  alias Forrozin.Accounts

  on_mount {ForrozinWeb.UserAuth, :redirect_if_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Cadastro", form: to_form(%{}, as: :usuario))}
  end

  @impl true
  def handle_event("registrar", %{"usuario" => params}, socket) do
    case Accounts.register_user(params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Conta criada! Verifique seu email para confirmar o cadastro.")
         |> redirect(to: ~p"/login")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :usuario))}
    end
  end
end
