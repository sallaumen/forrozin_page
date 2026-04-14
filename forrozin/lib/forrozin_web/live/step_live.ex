defmodule ForrozinWeb.StepLive do
  @moduledoc "Detail page for a single encyclopedia step."

  use ForrozinWeb, :live_view

  import Ecto.Query

  alias Forrozin.{Accounts, Admin, Encyclopedia}
  alias Forrozin.Encyclopedia.{Connection, Step}
  alias Forrozin.Repo

  on_mount {ForrozinWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(%{"code" => code}, _session, socket) do
    admin = Accounts.admin?(socket.assigns.current_user)
    user_id = socket.assigns.current_user.id

    case Encyclopedia.get_step_with_details(code, admin: admin) do
      {:ok, step} ->
        step = Repo.preload(step, :suggested_by)
        can_edit = admin or step.suggested_by_id == user_id

        connections_out = Repo.all(from c in Connection, where: c.source_step_id == ^step.id, preload: [:target_step])
        connections_in = Repo.all(from c in Connection, where: c.target_step_id == ^step.id, preload: [:source_step])

        {:ok,
         assign(socket,
           step: step,
           page_title: step.name,
           is_admin: admin,
           can_edit: can_edit,
           edit_mode: false,
           connections_out: connections_out,
           connections_in: connections_in,
           connection_search: "",
           connection_suggestions: [],
           categories: Encyclopedia.list_categories()
         )}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Passo não encontrado.")
         |> redirect(to: ~p"/collection")}
    end
  end

  @impl true
  def handle_event("toggle_edit", _params, socket) do
    {:noreply, assign(socket, edit_mode: not socket.assigns.edit_mode)}
  end

  def handle_event("update_step", %{"step" => params}, socket) do
    if not socket.assigns.can_edit, do: {:noreply, socket}

    case Admin.update_step(socket.assigns.step, params) do
      {:ok, updated} ->
        updated = Repo.preload(updated, [:category, :technical_concepts, :suggested_by, connections_as_source: :target_step, connections_as_target: :source_step])
        {:noreply, assign(socket, step: updated, page_title: updated.name) |> put_flash(:info, "Passo atualizado")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao salvar")}
    end
  end

  def handle_event("delete_step", _params, socket) do
    if not socket.assigns.is_admin do
      {:noreply, socket}
    else
      step = socket.assigns.step

      # Delete all connections first (cascade)
      Repo.delete_all(from c in Connection, where: c.source_step_id == ^step.id or c.target_step_id == ^step.id)

      case Admin.delete_step(step) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Passo \"#{step.name}\" deletado.")
           |> redirect(to: ~p"/collection")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Erro ao deletar passo")}
      end
    end
  end

  def handle_event("search_connection", %{"target_code" => term}, socket) do
    if not socket.assigns.can_edit or String.length(term) < 1 do
      {:noreply, assign(socket, connection_search: term, connection_suggestions: [])}
    else
      term_lower = String.downcase(term)

      suggestions =
        Repo.all(
          from s in Step,
            where: s.status == "published",
            where: fragment("lower(?) LIKE ? OR lower(?) LIKE ?", s.code, ^"%#{term_lower}%", s.name, ^"%#{term_lower}%"),
            order_by: [asc: s.name],
            limit: 8,
            preload: [:category]
        )

      {:noreply, assign(socket, connection_search: term, connection_suggestions: suggestions)}
    end
  end

  def handle_event("select_connection_target", %{"code" => code}, socket) do
    {:noreply, assign(socket, connection_search: code, connection_suggestions: [])}
  end

  def handle_event("create_connection", %{"target_code" => target_code}, socket) do
    if not socket.assigns.can_edit, do: {:noreply, socket}

    target = Repo.one(from s in Step, where: s.code == ^target_code)

    if is_nil(target) do
      {:noreply, put_flash(socket, :error, "Passo não encontrado")}
    else
      step = socket.assigns.step

      case Admin.create_connection(%{source_step_id: step.id, target_step_id: target.id}) do
        {:ok, _} -> {:noreply, reload_step(socket, step.code)}
        {:error, _} -> {:noreply, put_flash(socket, :error, "Conexão já existe")}
      end
    end
  end

  def handle_event("delete_connection", %{"source" => source_code, "target" => target_code}, socket) do
    if not socket.assigns.can_edit, do: {:noreply, socket}

    connection =
      Repo.one(
        from c in Connection,
          join: s in Step, on: c.source_step_id == s.id,
          join: t in Step, on: c.target_step_id == t.id,
          where: s.code == ^source_code and t.code == ^target_code
      )

    if connection do
      {:ok, _} = Admin.delete_connection(connection.id)
      {:noreply, reload_step(socket, socket.assigns.step.code)}
    else
      {:noreply, put_flash(socket, :error, "Conexão não encontrada")}
    end
  end

  defp reload_step(socket, code) do
    case Encyclopedia.get_step_with_details(code, admin: socket.assigns.is_admin) do
      {:ok, step} ->
        step = Repo.preload(step, :suggested_by)
        out = Repo.all(from c in Connection, where: c.source_step_id == ^step.id, preload: [:target_step])
        inn = Repo.all(from c in Connection, where: c.target_step_id == ^step.id, preload: [:source_step])

        assign(socket,
          step: step,
          connections_out: out,
          connections_in: inn,
          connection_search: "",
          connection_suggestions: []
        )

      _ ->
        socket
    end
  end

  def category_color(%{category: %{color: color}}), do: color
  def category_color(_), do: "#7f8c8d"

  def category_label(%{category: %{label: label}}), do: label
  def category_label(_), do: "—"
end
