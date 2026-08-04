defmodule OGrupoDeEstudosWeb.WorkshopProgramLive do
  @moduledoc """
  Public program page: the single link that goes to WhatsApp.

  It shows the workshops grouped by day, in the dancer's timezone, so the person
  sees the whole thing organized and picks where to go.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Brazil, Workshops}
  alias OGrupoDeEstudos.Authorization.Policy
  alias OGrupoDeEstudos.Workshops.{Workshop, WorkshopProgram}

  alias OGrupoDeEstudosWeb.{ChangesetErrors, InlineEditParams, Meta}

  import OGrupoDeEstudosWeb.UI.InlineEdit
  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.WorkshopComponents

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    program = Workshops.get_program_by_slug(slug)
    user = socket.assigns[:current_user]

    case Policy.authorize(:view_program, user, program) do
      :ok -> {:ok, assign_program(socket, program, user)}
      {:error, _} -> {:ok, not_found(socket)}
    end
  end

  defp open_field(socket, nil), do: socket

  defp open_field(socket, field) do
    if socket.assigns.owner? do
      socket |> assign(:editing_field, field) |> assign(:edit_error, nil)
    else
      socket
    end
  end

  defp close_field(socket), do: socket |> assign(:editing_field, nil) |> assign(:edit_error, nil)

  # The slug follows the title, so the page follows the slug instead of leaving a
  # dead address in the bar.
  defp reload_after_edit(socket, %{slug: slug} = updated) do
    if slug == socket.assigns.program.slug do
      assign(socket, :program, updated)
    else
      push_patch(socket, to: ~p"/programs/#{slug}")
    end
  end

  # The single link that goes to WhatsApp: the preview carries the program's own
  # name, blurb and flyer instead of the site-wide card.
  defp assign_link_preview(socket, program) do
    socket
    |> assign(:meta_title, "#{program.title} · O Grupo de Estudos")
    |> assign(:meta_description, Meta.summary(program.description))
    |> assign(:meta_url, url(~p"/programs/#{program.slug}"))
    |> assign_flyer_image(program)
  end

  defp assign_flyer_image(socket, %{flyer_path: nil}), do: socket

  defp assign_flyer_image(socket, program) do
    socket
    |> assign(:meta_image, url(~p"/programs/#{program.slug}/og-image"))
    |> assign(:meta_image_size, "1200")
  end

  defp assign_program(socket, program, user) do
    owner? = owner?(program, user)
    workshops = Workshops.list_program_workshops(program, include_drafts: owner?)

    socket
    |> assign(:page_title, program.title)
    |> assign_link_preview(program)
    |> assign(:program, program)
    |> assign(:owner?, owner?)
    |> assign(:editing_field, nil)
    |> assign(:edit_error, nil)
    |> assign(:is_admin, user && Accounts.admin?(user))
    |> assign(:days, group_by_day(workshops))
    |> assign(:workshop_count, length(workshops))
    |> assign(:enrolled_ids, enrolled_ids(user))
    |> assign(:enrollment_counts, Workshops.enrollment_counts(Enum.map(workshops, & &1.id)))
    |> assign_montagem(workshops, owner?, user)
    |> clear_selection(workshops, user)
    |> assign_pacote(program, workshops, user)
  end

  # Both ways to buy coexist: the closed package and the day-by-day choice.
  defp assign_pacote(socket, program, workshops, user) do
    socket
    |> assign(:tem_pacote?, WorkshopProgram.pacote?(program))
    |> assign(:avulso_total, Enum.sum(Enum.map(workshops, &(&1.price_cents || 0))))
    |> assign(:matricula_pacote, Workshops.package_enrollment(program, user))
    |> assign(
      :pacote_indisponivel,
      pacote_indisponivel(workshops, socket.assigns.enrollment_counts)
    )
  end

  # With one class full the package cannot be sold: whoever pays for three days
  # cannot get into two.
  defp pacote_indisponivel(workshops, contagens) do
    lotado =
      Enum.find(workshops, fn w ->
        w.status == :published and Workshop.full?(w, Map.get(contagens, w.id, 0))
      end)

    lotado &&
      "#{lotado.title} lotou, então o pacote fechado não dá. Dá para escolher os outros dias abaixo."
  end

  # Only offers a checkbox for what can be joined right now: published, with a
  # seat, and where the person is not already in.
  defp clear_selection(socket, workshops, user) do
    enrolled = socket.assigns.enrolled_ids
    contagens = socket.assigns.enrollment_counts

    selecionaveis =
      workshops
      |> Enum.filter(&can_check?(&1, user, enrolled, contagens))
      |> MapSet.new(& &1.id)

    socket
    |> assign(:selecionaveis, selecionaveis)
    |> assign(:selecionados, MapSet.intersection(selecionados(socket), selecionaveis))
  end

  defp can_check?(workshop, user, enrolled, contagens) do
    workshop.status == :published and
      not MapSet.member?(enrolled, workshop.id) and
      not Workshop.full?(workshop, Map.get(contagens, workshop.id, 0)) and
      not Workshops.admin?(workshop, user)
  end

  defp selecionados(%{assigns: %{selecionados: atual}}), do: atual
  defp selecionados(_socket), do: MapSet.new()

  # Assembly panel: only for the organizer, and only over what they administer.
  defp assign_montagem(socket, _workshops, false, _user) do
    socket
    |> assign(:dentro, [])
    |> assign(:disponiveis, [])
    |> assign(:pacotes, [])
    |> assign(:package_summary, nil)
  end

  defp assign_montagem(socket, workshops, true, user) do
    dentro_ids = MapSet.new(workshops, & &1.id)

    disponiveis =
      user.id
      |> Workshops.list_for_organizer()
      |> Enum.reject(&MapSet.member?(dentro_ids, &1.id))

    socket
    |> assign(:dentro, workshops)
    |> assign(:disponiveis, disponiveis)
    |> assign_pacotes(user)
  end

  defp assign_pacotes(socket, user) do
    program = socket.assigns.program
    {:ok, pacotes} = Workshops.list_package_enrollments(program, user)
    {:ok, summary} = Workshops.package_summary(program, user)

    socket |> assign(:pacotes, pacotes) |> assign(:package_summary, summary)
  end

  @impl true
  def handle_event("edit_field", %{"field" => field}, socket) do
    {:noreply, open_field(socket, InlineEditParams.program_field(field))}
  end

  def handle_event("cancel_edit", _params, socket), do: {:noreply, close_field(socket)}

  def handle_event("save_field", _params, %{assigns: %{editing_field: nil}} = socket),
    do: {:noreply, socket}

  def handle_event("save_field", params, socket) do
    field = socket.assigns.editing_field
    attrs = InlineEditParams.attrs(socket.assigns.program, field, params)

    case Workshops.update_program(socket.assigns.current_user, socket.assigns.program, attrs) do
      {:ok, updated} ->
        {:noreply, socket |> close_field() |> reload_after_edit(updated)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :edit_error, ChangesetErrors.first_message(changeset))}

      {:error, _unauthorized} ->
        {:noreply, close_field(socket)}
    end
  end

  @impl true
  def handle_event("publish", _params, socket) do
    user = socket.assigns.current_user

    case Workshops.publish_program(user, socket.assigns.program) do
      {:ok, program} ->
        {:noreply,
         socket
         |> assign_program(program, user)
         |> put_flash(:info, "Programação publicada! Agora é só compartilhar o link.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível publicar.")}
    end
  end

  def handle_event("set_package_payment", %{"id" => id, "status" => status}, socket)
      when status in ~w(pending paid waived) do
    user = socket.assigns.current_user

    case Workshops.set_package_payment(socket.assigns.program, user, id, payment(status)) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign_program(socket.assigns.program, user)
         |> put_flash(:info, "Pagamento do pacote atualizado.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível atualizar.")}
    end
  end

  def handle_event("set_package_payment", _params, socket), do: {:noreply, socket}

  def handle_event("buy_package", _params, %{assigns: %{current_user: nil}} = socket) do
    {:noreply, to_login(socket)}
  end

  def handle_event("buy_package", _params, socket) do
    user = socket.assigns.current_user

    case Workshops.enroll_in_package(socket.assigns.program, user) do
      {:ok, _matricula} ->
        {:noreply,
         socket
         |> assign_program(socket.assigns.program, user)
         |> put_flash(:info, "Pronto! Você está em todos os workshops da programação.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, package_error(reason))}
    end
  end

  def handle_event("toggle_selection", %{"id" => id}, socket) do
    case MapSet.member?(socket.assigns.selecionaveis, id) do
      true -> {:noreply, assign(socket, :selecionados, toggle(socket.assigns.selecionados, id))}
      false -> {:noreply, socket}
    end
  end

  def handle_event("confirm_enrollment", _params, %{assigns: %{current_user: nil}} = socket) do
    {:noreply, to_login(socket)}
  end

  def handle_event("confirm_enrollment", _params, socket) do
    user = socket.assigns.current_user
    escolhidos = MapSet.to_list(socket.assigns.selecionados)

    case Workshops.enroll_many(socket.assigns.program, user, escolhidos) do
      {:ok, resultado} ->
        {:noreply,
         socket
         |> assign(:selecionados, MapSet.new())
         |> assign_program(socket.assigns.program, user)
         |> put_flash(tone(resultado), batch_summary(resultado))}

      {:error, :none_selected} ->
        {:noreply, put_flash(socket, :error, "Marque pelo menos um workshop.")}
    end
  end

  def handle_event("attach_workshop", %{"id" => id}, socket) do
    build(socket, id, &Workshops.attach_workshop/3, "Workshop adicionado à programação.")
  end

  def handle_event("detach_workshop", %{"id" => id}, socket) do
    build(socket, id, &Workshops.detach_workshop/3, "Workshop tirado da programação.")
  end

  defp payment("paid"), do: :paid
  defp payment("waived"), do: :waived
  defp payment(_pending), do: :pending

  defp package_error({:full, workshop}),
    do: "#{workshop.title} lotou, então o pacote não deu. Escolha os dias que ainda têm vaga."

  defp package_error(:already_enrolled), do: "Você já tem a programação toda."
  defp package_error(:organizer), do: "Você organiza esta programação."
  defp package_error(:no_package), do: "Esta programação não tem preço fechado."
  defp package_error(_other), do: "Não foi possível confirmar o pacote."

  defp toggle(selecionados, id) do
    case MapSet.member?(selecionados, id) do
      true -> MapSet.delete(selecionados, id)
      false -> MapSet.put(selecionados, id)
    end
  end

  defp tone(%{enrolled: []}), do: :error
  defp tone(_resultado), do: :info

  # Names what failed: "one did not work" says neither which nor why.
  defp batch_summary(%{enrolled: [], failed: [{workshop, reason} | _]}) do
    "#{workshop.title} não deu: #{error_reason(reason)}"
  end

  defp batch_summary(%{enrolled: enrolled, failed: []}) do
    "#{confirmadas(length(enrolled))} Te vejo lá."
  end

  defp batch_summary(%{enrolled: enrolled, failed: [{workshop, reason} | _]}) do
    "#{confirmadas(length(enrolled))} #{workshop.title} não deu: #{error_reason(reason)}"
  end

  defp confirmadas(1), do: "1 inscrição confirmada."
  defp confirmadas(total), do: "#{total} inscrições confirmadas."

  defp error_reason(:full), do: "as vagas acabaram."
  defp error_reason(:not_open), do: "não está aberto para inscrição."
  defp error_reason(:organizer), do: "você organiza esse."
  defp error_reason(_other), do: "não foi possível inscrever."

  # The id comes from params on a public page: only the organizer changes it, and
  # the real authorization lives in the context, which checks both sides.
  defp build(%{assigns: %{owner?: false}} = socket, _id, _fun, _mensagem),
    do: {:noreply, socket}

  defp build(socket, id, fun, mensagem) do
    user = socket.assigns.current_user

    case fun.(socket.assigns.program, user, id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign_program(socket.assigns.program, user)
         |> put_flash(:info, mensagem)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível mexer nessa programação.")}
    end
  end

  defp not_found(socket) do
    socket
    |> put_flash(:error, "Programação não encontrada.")
    |> redirect(to: ~p"/study/workshops")
  end

  defp owner?(_program, nil), do: false
  defp owner?(program, user), do: program.owner_id == user.id

  # Not signed in: login already offers Google and links to signup, and the
  # program travels along so the person lands back where they stopped.
  defp to_login(socket) do
    redirect(socket, to: ~p"/login?#{[return_to: ~p"/programs/#{socket.assigns.program.slug}"]}")
  end

  defp enrolled_ids(nil), do: MapSet.new()
  defp enrolled_ids(user), do: Workshops.enrolled_workshop_ids(user.id)

  # Groups by the LOCAL day: a workshop at 20h on a Thursday in Brasília is 23h
  # UTC on Thursday, but one at 22h would already be Friday in UTC and land on
  # the wrong day.
  defp group_by_day(workshops) do
    workshops
    |> Enum.group_by(&(&1.starts_at |> Brazil.to_local() |> DateTime.to_date()))
    |> Enum.sort_by(fn {date, _} -> date end, Date)
  end

  @doc false
  def payment_tone(:paid), do: :green
  def payment_tone(:waived), do: :neutral
  def payment_tone(_pending), do: :orange

  @doc false
  def selecao_label(0), do: "Marque os workshops que você vai."
  def selecao_label(1), do: "1 workshop marcado."
  def selecao_label(total), do: "#{total} workshops marcados."

  @doc false
  def day_heading(date) do
    Brazil.strftime(date, "%A, %d de %B")
  end
end
