defmodule OGrupoDeEstudosWeb.WorkshopFormLive do
  @moduledoc """
  Creates and edits a workshop. The same form serves both cases: the difference
  is in `live_action` (`:new` / `:edit`) and in the primary button.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Brazil, Workshops}
  alias OGrupoDeEstudos.Authorization.Policy
  alias OGrupoDeEstudos.Workshops.Workshop
  alias OGrupoDeEstudosWeb.ChangesetErrors

  on_mount {OGrupoDeEstudosWeb.Navigation, :primary}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.WorkshopComponents

  @doc "Brazilian states for the select."
  @spec state_options() :: [String.t()]
  def state_options, do: Brazil.states()

  @doc "Shared field classes, so eight address inputs do not repeat the same string."
  @spec input_class() :: String.t()
  def input_class,
    do:
      "w-full rounded-lg border border-ink-200 bg-ink-50 px-3 py-2.5 font-serif text-sm text-ink-800 placeholder:text-ink-400"

  @spec label_class() :: String.t()
  def label_class,
    do: "mb-1.5 block text-[10px] font-bold uppercase tracking-[1.3px] text-ink-500"

  # What a dance workshop actually lasts. Anything outside this is either an event
  # across days or an odd length that was typed before: both fall back to the end
  # date, which stays reachable instead of being taken away.
  @durations [
    {"60", "1 hora"},
    {"90", "1h30"},
    {"120", "2 horas"},
    {"150", "2h30"},
    {"180", "3 horas"},
    {"240", "4 horas"},
    {"300", "5 horas"},
    {"360", "6 horas"}
  ]

  @doc "Duration options for the select, as `{value, label}`."
  @spec duration_options() :: [{String.t(), String.t()}]
  def duration_options, do: @durations

  @impl true
  def mount(params, _session, socket) do
    {:ok, mount_for(socket, socket.assigns.live_action, params)}
  end

  # Only creating asks `:create_workshop`. Editing asks `:manage_workshop`, inside
  # prepare/3: whoever organized a workshop before the rule tightened keeps editing
  # it even without teaching, because owning it is a different question.
  defp mount_for(socket, :new, params) do
    case Policy.authorize(:create_workshop, socket.assigns.current_user, nil) do
      :ok -> allow_flyer(prepare(socket, :new, params))
      {:error, _} -> redirect(socket, to: ~p"/study/workshops")
    end
  end

  defp mount_for(socket, :edit, params), do: allow_flyer(prepare(socket, :edit, params))

  defp allow_flyer(socket) do
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

  # Both buttons submit the same form and differ by name/value, so the fields come
  # from the DOM instead of depending on the assign that phx-change syncs.
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
        workshop = store_flyer(socket, workshop, user)
        store_teachers(workshop, user, params)

        # If publishing fails inside finish/4, the LiveView stays open: the
        # retry must take the update path, or the click creates a duplicate
        # while the first workshop lingers as an invisible draft.
        socket
        |> assign(:workshop, workshop)
        |> finish(user, workshop, publish?)

      {:error, changeset} ->
        {:noreply, form_failed(socket, params, changeset)}
    end
  end

  defp submit(socket, workshop, params, publish?: publish?) do
    user = socket.assigns.current_user
    waiting_before = Workshops.waitlist_count(workshop.id)

    case Workshops.update_workshop(user, workshop, to_attrs(params)) do
      {:ok, updated} ->
        store_teachers(updated, user, params)
        promoted = waiting_before - Workshops.waitlist_count(updated.id)

        socket
        |> assign(:promoted_note, promoted_note(promoted))
        |> finish(user, store_flyer(socket, updated, user), publish?)

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, form_failed(socket, params, changeset)}

      {:error, :unauthorized} ->
        {:noreply, redirect(socket, to: ~p"/study/workshops")}
    end
  end

  # `?program=slug` makes the workshop start inside the program. It only applies
  # when the person owns it: otherwise the workshop starts loose, without complaint.
  defp program_from(%{"program" => slug}, user) do
    program = Workshops.get_program_by_slug(slug)

    if program && Policy.authorized?(:manage_program, user, program), do: program, else: nil
  end

  defp program_from(_params, _user), do: nil

  # The upload does not block saving: if the flyer fails, the workshop exists all
  # the same and the poster can be retried later.
  defp store_flyer(socket, workshop, user) do
    socket
    |> consume_uploaded_entries(:flyer, fn %{path: tmp_path}, entry ->
      {:ok, Workshops.put_workshop_flyer(workshop, user, tmp_path, extension(entry))}
    end)
    |> case do
      [{:ok, atualizado}] -> atualizado
      _ -> workshop
    end
  end

  defp extension(entry) do
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
         |> put_flash(
           :info,
           "Workshop publicado! Agora é só compartilhar o link." <> promoted_suffix(socket)
         )
         |> redirect(to: ~p"/workshops/#{published.slug}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível publicar.")}
    end
  end

  defp finish(socket, _user, workshop, false) do
    {:noreply,
     socket
     |> put_flash(
       :info,
       "Rascunho salvo. Publique quando estiver pronto." <> promoted_suffix(socket)
     )
     |> redirect(to: ~p"/workshops/#{workshop.slug}")}
  end

  defp promoted_suffix(socket), do: socket.assigns[:promoted_note] || ""

  defp promoted_note(1),
    do: " 1 pessoa da lista de espera ganhou a vaga e foi avisada por email."

  defp promoted_note(promoted) when promoted > 1,
    do: " #{promoted} pessoas da lista de espera ganharam a vaga e foram avisadas por email."

  defp promoted_note(_none_or_negative), do: ""

  defp form_failed(socket, params, changeset) do
    socket
    |> assign(:form, Map.merge(socket.assigns.form, params))
    |> assign(:form_error, first_error(changeset))
  end

  # The label and the message together, so "não pode ficar em branco" says which
  # field it is talking about.
  defp first_error(changeset) do
    case Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end) do
      map when map == %{} -> "Confira os campos e tente de novo."
      map -> "#{label_for(first_field(map))} #{ChangesetErrors.first_message(changeset)}"
    end
  end

  defp first_field(errors), do: errors |> Map.keys() |> List.first()

  defp label_for(:title), do: "Título"
  defp label_for(:description), do: "Descrição"
  defp label_for(:starts_at), do: "Data de início"
  defp label_for(:ends_at), do: "Data de término"
  defp label_for(:duration_minutes), do: "Duração"
  defp label_for(:city), do: "Cidade"
  defp label_for(:state), do: "Estado"
  defp label_for(:street), do: "Rua"
  defp label_for(:capacity), do: "Vagas"
  defp label_for(:price_cents), do: "Preço"
  defp label_for(field), do: field |> to_string() |> String.capitalize()

  defp empty_form do
    %{
      "title" => "",
      "description" => "",
      "starts_at" => "",
      "duration" => "120",
      "ends_at" => "",
      "price" => "",
      "payment_info" => "",
      "payment_mode" => "",
      "teacher_username" => [],
      "teacher_name" => [],
      "payment_phone" => "",
      "capacity" => "",
      "visibility" => "public"
    }
    |> Map.merge(address_form(%Workshop{}))
  end

  defp form_from(workshop) do
    %{
      "title" => workshop.title,
      "description" => workshop.description,
      "starts_at" => datetime_input(workshop.starts_at),
      "duration" => duration_input(workshop),
      "ends_at" => datetime_input(workshop.ends_at),
      "price" => price_input(workshop.price_cents),
      "payment_info" => workshop.payment_info || "",
      "payment_mode" => to_string(workshop.payment_mode || ""),
      "teacher_username" => Enum.map(Workshops.list_teachers(workshop.id), &(&1.username || "")),
      "teacher_name" =>
        Enum.map(Workshops.list_teachers(workshop.id), fn p ->
          if p.username, do: "", else: p.name
        end),
      "payment_phone" => workshop.payment_phone || "",
      "capacity" => if(workshop.capacity, do: to_string(workshop.capacity), else: ""),
      "visibility" => to_string(workshop.visibility)
    }
    |> Map.merge(address_form(workshop))
  end

  @address_fields ~w(location street street_number complement neighborhood city state postal_code)a

  defp address_form(workshop) do
    Map.new(@address_fields, fn field ->
      {to_string(field), Map.get(workshop, field) || ""}
    end)
  end

  # "custom" means the select cannot say it: no end at all, an odd length, or an
  # event across days. The end date field appears and answers for those.
  defp duration_input(%{starts_at: %DateTime{}, ends_at: %DateTime{}} = workshop) do
    minutes = DateTime.diff(workshop.ends_at, workshop.starts_at, :minute)

    if Enum.any?(@durations, fn {value, _label} -> value == to_string(minutes) end),
      do: to_string(minutes),
      else: "custom"
  end

  defp duration_input(_no_end), do: "custom"

  # The datetime-local input works in the user timezone; the database stores UTC.
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
      payment_info: blank_to_nil(params["payment_info"]),
      payment_mode: payment_mode_from(params["payment_mode"]),
      payment_phone: blank_to_nil(params["payment_phone"]),
      starts_at: parse_datetime(params["starts_at"]),
      duration_minutes: parse_int(params["duration"]),
      ends_at: parse_datetime(params["ends_at"]),
      price_cents: parse_price(params["price"]),
      capacity: parse_int(params["capacity"]),
      visibility: visibilidade(params["visibility"])
    }
    |> Map.merge(address_attrs(params))
  end

  defp address_attrs(params) do
    Map.new(@address_fields, fn field ->
      {field, blank_to_nil(params[to_string(field)])}
    end)
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

  # Pattern matching instead of String.to_existing_atom: a form value is outside
  # input, and an atom that does not exist yet would bring the page down.
  defp payment_mode_from("on_signup"), do: :on_signup
  defp payment_mode_from("at_event"), do: :at_event
  defp payment_mode_from(_nada), do: nil

  # Teachers are written apart from the workshop: the list is another table, and
  # failing here cannot undo the workshop that was already created. A username
  # that does not exist simply does not go in, and the rest does.
  defp store_teachers(workshop, user, params) do
    entradas =
      [0, 1]
      |> Enum.map(&teacher_entry(params, &1))
      |> Enum.reject(&is_nil/1)

    Workshops.set_teachers(workshop, user, entradas)
  end

  defp teacher_entry(params, indice) do
    user = list_field(params["teacher_username"], indice)
    name = list_field(params["teacher_name"], indice)

    cond do
      user -> account_by_username(user)
      name -> %{display_name: name}
      true -> nil
    end
  end

  defp account_by_username(username) do
    case OGrupoDeEstudos.Accounts.get_user_by_username(username) do
      nil -> nil
      %{id: id} -> %{user_id: id}
    end
  end

  @doc """
  Reads the teacher field at the given position.

  The browser sends `teacher_username` as a list when the form is new and as a map
  indexed by position after a validation error, so both shapes are handled.
  """
  @spec teacher_field(term(), non_neg_integer()) :: String.t()
  def teacher_field(valores, indice), do: list_field(valores, indice) || ""

  defp list_field(nil, _indice), do: nil

  defp list_field(valores, indice) when is_map(valores),
    do: valores |> Map.get(to_string(indice)) |> blank_to_nil()

  defp list_field(valores, indice) when is_list(valores),
    do: valores |> Enum.at(indice) |> blank_to_nil()

  defp list_field(_other_format, _indice), do: nil
end
