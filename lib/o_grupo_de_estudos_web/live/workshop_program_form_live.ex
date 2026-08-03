defmodule OGrupoDeEstudosWeb.WorkshopProgramFormLive do
  @moduledoc """
  Cria e edita uma programação, e escolhe quais workshops entram nela.

  A lista de escolha só traz workshops que a pessoa administra: entrar numa
  programação exige mandar nos dois lados.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Workshops}
  alias OGrupoDeEstudos.Authorization.Policy

  on_mount {OGrupoDeEstudosWeb.Navigation, :primary}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  use OGrupoDeEstudosWeb.NotificationHandlers

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.WorkshopComponents

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_user

    case Policy.authorize(:create_program, user, nil) do
      :ok -> {:ok, permitir_flyer(prepare(socket, socket.assigns.live_action, params))}
      {:error, _} -> {:ok, redirect(socket, to: ~p"/study/workshops")}
    end
  end

  defp permitir_flyer(socket) do
    allow_upload(socket, :flyer,
      accept: ~w(.jpg .jpeg .png .webp),
      max_entries: 1,
      max_file_size: 8_000_000
    )
  end

  defp prepare(socket, :new, _params) do
    socket
    |> base_assigns("Nova programação")
    |> assign(:program, nil)
    |> assign(:form, %{"title" => "", "description" => "", "location" => ""})
  end

  defp prepare(socket, :edit, %{"slug" => slug}) do
    program = Workshops.get_program_by_slug(slug)
    user = socket.assigns.current_user

    if program && Policy.authorized?(:manage_program, user, program) do
      socket
      |> base_assigns("Editar programação")
      |> assign(:program, program)
      |> assign(:form, form_from(program))
      |> load_selection()
    else
      socket
      |> put_flash(:error, "Programação não encontrada.")
      |> redirect(to: ~p"/study/workshops")
    end
  end

  defp base_assigns(socket, title) do
    user = socket.assigns.current_user

    socket
    |> assign(:page_title, title)
    |> assign(:is_admin, Accounts.admin?(user))
    |> assign(:form_error, nil)
    |> assign(:my_workshops, Workshops.list_for_organizer(user.id))
    |> assign(:selected_ids, MapSet.new())
  end

  # Marca os que ja estao nesta programacao.
  defp load_selection(socket) do
    ids =
      socket.assigns.program
      |> Workshops.list_program_workshops(include_drafts: true)
      |> MapSet.new(& &1.id)

    assign(socket, :selected_ids, ids)
  end

  @impl true
  def handle_event("validate", %{"program" => params}, socket) do
    {:noreply, assign(socket, :form, Map.merge(socket.assigns.form, params))}
  end

  def handle_event("toggle_workshop", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_ids, toggle(socket.assigns.selected_ids, id))}
  end

  def handle_event("remove_flyer", _params, socket) do
    user = socket.assigns.current_user

    case Workshops.remove_program_flyer(socket.assigns.program, user) do
      {:ok, atualizado} -> {:noreply, assign(socket, :program, atualizado)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Não foi possível tirar o flyer.")}
    end
  end

  def handle_event("save", %{"program" => params}, socket) do
    submit(socket, socket.assigns.program, params)
  end

  defp toggle(selected, id) do
    case MapSet.member?(selected, id) do
      true -> MapSet.delete(selected, id)
      false -> MapSet.put(selected, id)
    end
  end

  defp submit(socket, nil, params) do
    user = socket.assigns.current_user

    case Workshops.create_program(user, to_attrs(params)) do
      {:ok, program} -> finish(socket, program)
      {:error, changeset} -> {:noreply, form_failed(socket, params, changeset)}
    end
  end

  defp submit(socket, program, params) do
    user = socket.assigns.current_user

    case Workshops.update_program(user, program, to_attrs(params)) do
      {:ok, updated} ->
        finish(socket, updated)

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, form_failed(socket, params, changeset)}

      {:error, :unauthorized} ->
        {:noreply, redirect(socket, to: ~p"/study/workshops")}
    end
  end

  # A selecao e aplicada depois de salvar: atachar exige a programacao existir.
  defp finish(socket, program) do
    user = socket.assigns.current_user
    sync_workshops(program, user, socket.assigns.selected_ids)
    guardar_flyer(socket, program, user)

    {:noreply,
     socket
     |> put_flash(:info, "Programação salva. Agora é só compartilhar o link.")
     |> redirect(to: ~p"/programacao/#{program.slug}")}
  end

  # Nao bloqueia o salvamento: se o cartaz falhar, a programacao existe e a
  # pessoa tenta a imagem de novo.
  defp guardar_flyer(socket, program, user) do
    consume_uploaded_entries(socket, :flyer, fn %{path: tmp_path}, entry ->
      {:ok, Workshops.put_program_flyer(program, user, tmp_path, extensao(entry))}
    end)
  end

  defp extensao(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    "." <> ext
  end

  defp sync_workshops(program, user, selected) do
    atuais =
      program
      |> Workshops.list_program_workshops(include_drafts: true)
      |> MapSet.new(& &1.id)

    for id <- MapSet.difference(selected, atuais),
        do: Workshops.attach_workshop(program, user, id)

    for id <- MapSet.difference(atuais, selected),
        do: Workshops.detach_workshop(program, user, id)
  end

  defp form_failed(socket, params, changeset) do
    socket
    |> assign(:form, Map.merge(socket.assigns.form, params))
    |> assign(:form_error, first_error(changeset))
  end

  defp first_error(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map(fn {field, [msg | _]} -> "#{label_for(field)} #{msg}" end)
    |> List.first()
    |> Kernel.||("Confira os campos e tente de novo.")
  end

  defp label_for(:title), do: "Título"
  defp label_for(:description), do: "Descrição"
  defp label_for(field), do: field |> to_string() |> String.capitalize()

  defp form_from(program) do
    %{
      "title" => program.title,
      "description" => program.description || "",
      "location" => program.location || ""
    }
  end

  defp to_attrs(params) do
    %{
      title: params["title"],
      description: blank_to_nil(params["description"]),
      location: blank_to_nil(params["location"])
    }
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: String.trim(value)
end
