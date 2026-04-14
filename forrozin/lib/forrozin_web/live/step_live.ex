defmodule ForrozinWeb.StepLive do
  @moduledoc "Detail page for a single encyclopedia step."

  use ForrozinWeb, :live_view

  alias Forrozin.Accounts
  alias Forrozin.Encyclopedia

  on_mount {ForrozinWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(%{"code" => code}, _session, socket) do
    admin = Accounts.admin?(socket.assigns.current_user)

    case Encyclopedia.get_step_with_details(code, admin: admin) do
      {:ok, step} ->
        {:ok, assign(socket, step: step, page_title: step.name)}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Passo não encontrado.")
         |> redirect(to: ~p"/collection")}
    end
  end

  def category_color(%{category: %{color: color}}), do: color
  def category_color(_), do: "#7f8c8d"

  def category_label(%{category: %{label: label}}), do: label
  def category_label(_), do: "—"
end
