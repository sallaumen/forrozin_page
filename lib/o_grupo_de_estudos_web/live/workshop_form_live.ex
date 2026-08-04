defmodule OGrupoDeEstudosWeb.WorkshopFormLive do
  @moduledoc """
  Criar e editar workshop. O mesmo formulário serve aos dois casos: a
  diferença está no `live_action` (`:new` / `:edit`) e no botão principal.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Brazil, Workshops}
  alias OGrupoDeEstudos.Authorization.Policy

  on_mount {OGrupoDeEstudosWeb.Navigation, :primary}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.WorkshopComponents

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_user

    case Policy.authorize(:create_workshop, user, nil) do
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

  defp prepare(socket, :new, params) do
    socket
    |> assign(:page_title, "Novo workshop")
    |> assign(:is_admin, Accounts.admin?(socket.assigns.current_user))
    |> assign(:workshop, nil)
    |> assign(:form_error, nil)
    |> assign(:form, empty_form())
    |> assign(:program, program_from(params, socket.assigns.current_user))
  end

  defp prepare(socket, :edit, %{"slug" => slug}) do
    workshop = Workshops.get_by_slug(slug)
    user = socket.assigns.current_user

    if workshop &&
         Policy.authorized?(:manage_workshop, user, Workshops.access_for(workshop, user)) do
      socket
      |> assign(:page_title, "Editar workshop")
      |> assign(:is_admin, Accounts.admin?(user))
      |> assign(:workshop, workshop)
      |> assign(:form_error, nil)
      |> assign(:program, nil)
      |> assign(:form, form_from(workshop))
    else
      socket
      |> put_flash(:error, "Workshop não encontrado.")
      |> redirect(to: ~p"/study/workshops")
    end
  end

  @impl true
  def handle_event("validate", %{"workshop" => params}, socket) do
    {:noreply, assign(socket, :form, Map.merge(socket.assigns.form, params))}
  end

  # Os dois botões submetem o mesmo form e se distinguem pelo name/value: assim
  # os campos vêm do DOM, sem depender do assign que o phx-change sincroniza.
  def handle_event("remove_flyer", _params, socket) do
    user = socket.assigns.current_user

    case Workshops.remove_workshop_flyer(socket.assigns.workshop, user) do
      {:ok, atualizado} -> {:noreply, assign(socket, :workshop, atualizado)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Não foi possível tirar o flyer.")}
    end
  end

  def handle_event("save", %{"workshop" => params} = event, socket) do
    submit(socket, socket.assigns.workshop, params, publish?: event["publish"] == "true")
  end

  defp submit(socket, nil, params, publish?: publish?) do
    user = socket.assigns.current_user

    case Workshops.create_workshop(user, to_attrs(params)) do
      {:ok, workshop} ->
        attach_to_program(socket.assigns[:program], user, workshop)
        workshop = guardar_flyer(socket, workshop, user)
        finish(socket, user, workshop, publish?)

      {:error, changeset} ->
        {:noreply, form_failed(socket, params, changeset)}
    end
  end

  defp submit(socket, workshop, params, publish?: publish?) do
    user = socket.assigns.current_user

    case Workshops.update_workshop(user, workshop, to_attrs(params)) do
      {:ok, updated} ->
        finish(socket, user, guardar_flyer(socket, updated, user), publish?)

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, form_failed(socket, params, changeset)}

      {:error, :unauthorized} ->
        {:noreply, redirect(socket, to: ~p"/study/workshops")}
    end
  end

  # `?programa=slug` faz o workshop nascer ja dentro da programacao. So vale
  # se a pessoa e dona dela: senao o workshop nasce solto, sem reclamar.
  defp program_from(%{"programa" => slug}, user) do
    program = Workshops.get_program_by_slug(slug)

    if program && Policy.authorized?(:manage_program, user, program), do: program, else: nil
  end

  defp program_from(_params, _user), do: nil

  # O upload nao bloqueia o salvamento: se o flyer falhar, o workshop existe
  # do mesmo jeito e a pessoa tenta o cartaz de novo depois.
  defp guardar_flyer(socket, workshop, user) do
    socket
    |> consume_uploaded_entries(:flyer, fn %{path: tmp_path}, entry ->
      {:ok, Workshops.put_workshop_flyer(workshop, user, tmp_path, extensao(entry))}
    end)
    |> case do
      [{:ok, atualizado}] -> atualizado
      _ -> workshop
    end
  end

  defp extensao(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    "." <> ext
  end

  defp attach_to_program(nil, _user, _workshop), do: :ok

  defp attach_to_program(program, user, workshop),
    do: Workshops.attach_workshop(program, user, workshop.id)

  defp finish(socket, user, workshop, true) do
    case Workshops.publish_workshop(user, workshop) do
      {:ok, published} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workshop publicado! Agora é só compartilhar o link.")
         |> redirect(to: ~p"/workshops/#{published.slug}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível publicar.")}
    end
  end

  defp finish(socket, _user, workshop, false) do
    {:noreply,
     socket
     |> put_flash(:info, "Rascunho salvo. Publique quando estiver pronto.")
     |> redirect(to: ~p"/workshops/#{workshop.slug}")}
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
  defp label_for(:starts_at), do: "Data de início"
  defp label_for(:ends_at), do: "Data de término"
  defp label_for(:capacity), do: "Vagas"
  defp label_for(:price_cents), do: "Preço"
  defp label_for(field), do: field |> to_string() |> String.capitalize()

  defp empty_form do
    %{
      "title" => "",
      "description" => "",
      "location" => "",
      "starts_at" => "",
      "ends_at" => "",
      "price" => "",
      "payment_info" => "",
      "payment_mode" => "",
      "payment_phone" => "",
      "capacity" => "",
      "visibility" => "public"
    }
  end

  defp form_from(workshop) do
    %{
      "title" => workshop.title,
      "description" => workshop.description,
      "location" => workshop.location || "",
      "starts_at" => datetime_input(workshop.starts_at),
      "ends_at" => datetime_input(workshop.ends_at),
      "price" => price_input(workshop.price_cents),
      "payment_info" => workshop.payment_info || "",
      "payment_mode" => to_string(workshop.payment_mode || ""),
      "payment_phone" => workshop.payment_phone || "",
      "capacity" => if(workshop.capacity, do: to_string(workshop.capacity), else: ""),
      "visibility" => to_string(workshop.visibility)
    }
  end

  # O input datetime-local trabalha no fuso do usuário; o banco guarda UTC.
  defp datetime_input(nil), do: ""

  defp datetime_input(datetime) do
    datetime |> Brazil.to_local() |> Calendar.strftime("%Y-%m-%dT%H:%M")
  end

  defp price_input(nil), do: ""
  defp price_input(cents), do: :erlang.float_to_binary(cents / 100, decimals: 2)

  defp to_attrs(params) do
    %{
      title: params["title"],
      description: params["description"],
      location: blank_to_nil(params["location"]),
      payment_info: blank_to_nil(params["payment_info"]),
      payment_mode: modo_de_pagamento(params["payment_mode"]),
      payment_phone: blank_to_nil(params["payment_phone"]),
      starts_at: parse_datetime(params["starts_at"]),
      ends_at: parse_datetime(params["ends_at"]),
      price_cents: parse_price(params["price"]),
      capacity: parse_int(params["capacity"]),
      visibility: visibilidade(params["visibility"])
    }
  end

  defp visibilidade("private"), do: :private
  defp visibilidade(_public), do: :public

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: String.trim(value)

  defp parse_datetime(nil), do: nil
  defp parse_datetime(""), do: nil

  defp parse_datetime(value) do
    case NaiveDateTime.from_iso8601(value <> ":00") do
      {:ok, naive} ->
        naive
        |> DateTime.from_naive!("Etc/UTC")
        |> Brazil.to_utc()
        |> DateTime.truncate(:second)

      {:error, _} ->
        nil
    end
  end

  defp parse_price(nil), do: nil
  defp parse_price(""), do: nil

  defp parse_price(value) do
    case value |> String.replace(",", ".") |> Float.parse() do
      {reais, _} -> round(reais * 100)
      :error -> nil
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil

  defp parse_int(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  # Pattern matching em vez de String.to_existing_atom: valor de formulario e
  # entrada de fora, e um atomo que ainda nao existe derrubaria a pagina.
  defp modo_de_pagamento("on_signup"), do: :on_signup
  defp modo_de_pagamento("at_event"), do: :at_event
  defp modo_de_pagamento(_nada), do: nil
end
