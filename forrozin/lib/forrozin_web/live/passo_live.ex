defmodule ForrozinWeb.PassoLive do
  @moduledoc "Página de detalhe de um passo da enciclopédia."

  use ForrozinWeb, :live_view

  alias Forrozin.Accounts
  alias Forrozin.Enciclopedia

  on_mount {ForrozinWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(%{"codigo" => codigo}, _session, socket) do
    admin = Accounts.admin?(socket.assigns.current_user)

    case Enciclopedia.buscar_passo_com_detalhes(codigo, admin: admin) do
      {:ok, passo} ->
        {:ok, assign(socket, passo: passo, page_title: passo.nome)}

      {:error, :nao_encontrado} ->
        {:ok,
         socket
         |> put_flash(:error, "Passo não encontrado.")
         |> redirect(to: ~p"/acervo")}
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers públicos (usados no template)
  # ---------------------------------------------------------------------------

  def categoria_cor(%{categoria: %{cor: cor}}), do: cor
  def categoria_cor(_), do: "#7f8c8d"

  def rotulo_categoria(%{categoria: %{rotulo: rotulo}}), do: rotulo
  def rotulo_categoria(_), do: "—"
end
