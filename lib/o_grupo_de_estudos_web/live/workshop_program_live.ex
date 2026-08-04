defmodule OGrupoDeEstudosWeb.WorkshopProgramLive do
  @moduledoc """
  Página pública da programação: o link único que vai para o WhatsApp.

  Mostra os workshops agrupados por dia, no fuso de quem dança, para a pessoa
  entender de uma olhada o que acontece na quinta e o que acontece na sexta.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Brazil, Workshops}
  alias OGrupoDeEstudos.Authorization.Policy
  alias OGrupoDeEstudos.Workshops.{Workshop, WorkshopProgram}

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

  defp assign_program(socket, program, user) do
    owner? = owner?(program, user)
    workshops = Workshops.list_program_workshops(program, include_drafts: owner?)

    socket
    |> assign(:page_title, program.title)
    |> assign(:program, program)
    |> assign(:owner?, owner?)
    |> assign(:is_admin, user && Accounts.admin?(user))
    |> assign(:days, group_by_day(workshops))
    |> assign(:workshop_count, length(workshops))
    |> assign(:enrolled_ids, enrolled_ids(user))
    |> assign(:enrollment_counts, Workshops.enrollment_counts(Enum.map(workshops, & &1.id)))
    |> assign_montagem(workshops, owner?, user)
    |> limpar_selecao(workshops, user)
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
  defp limpar_selecao(socket, workshops, user) do
    inscritos = socket.assigns.enrolled_ids
    contagens = socket.assigns.enrollment_counts

    selecionaveis =
      workshops
      |> Enum.filter(&pode_marcar?(&1, user, inscritos, contagens))
      |> MapSet.new(& &1.id)

    socket
    |> assign(:selecionaveis, selecionaveis)
    |> assign(:selecionados, MapSet.intersection(selecionados(socket), selecionaveis))
  end

  defp pode_marcar?(workshop, user, inscritos, contagens) do
    workshop.status == :published and
      not MapSet.member?(inscritos, workshop.id) and
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
    |> assign(:resumo_pacote, nil)
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
    {:ok, resumo} = Workshops.package_summary(program, user)

    socket |> assign(:pacotes, pacotes) |> assign(:resumo_pacote, resumo)
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

    case Workshops.set_package_payment(socket.assigns.program, user, id, pagamento(status)) do
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
    {:noreply, redirect(socket, to: ~p"/signup?#{[programa: socket.assigns.program.slug]}")}
  end

  def handle_event("buy_package", _params, socket) do
    user = socket.assigns.current_user

    case Workshops.enroll_in_package(socket.assigns.program, user) do
      {:ok, _matricula} ->
        {:noreply,
         socket
         |> assign_program(socket.assigns.program, user)
         |> put_flash(:info, "Pronto! Você está em todos os workshops da programação.")}

      {:error, motivo} ->
        {:noreply, put_flash(socket, :error, erro_do_pacote(motivo))}
    end
  end

  def handle_event("toggle_selection", %{"id" => id}, socket) do
    case MapSet.member?(socket.assigns.selecionaveis, id) do
      true -> {:noreply, assign(socket, :selecionados, alternar(socket.assigns.selecionados, id))}
      false -> {:noreply, socket}
    end
  end

  def handle_event("confirm_enrollment", _params, %{assigns: %{current_user: nil}} = socket) do
    {:noreply, redirect(socket, to: ~p"/signup?#{[programa: socket.assigns.program.slug]}")}
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
         |> put_flash(tom(resultado), resumo_do_lote(resultado))}

      {:error, :none_selected} ->
        {:noreply, put_flash(socket, :error, "Marque pelo menos um workshop.")}
    end
  end

  def handle_event("attach_workshop", %{"id" => id}, socket) do
    montar(socket, id, &Workshops.attach_workshop/3, "Workshop adicionado à programação.")
  end

  def handle_event("detach_workshop", %{"id" => id}, socket) do
    montar(socket, id, &Workshops.detach_workshop/3, "Workshop tirado da programação.")
  end

  defp pagamento("paid"), do: :paid
  defp pagamento("waived"), do: :waived
  defp pagamento(_pending), do: :pending

  defp erro_do_pacote({:full, workshop}),
    do: "#{workshop.title} lotou, então o pacote não deu. Escolha os dias que ainda têm vaga."

  defp erro_do_pacote(:already_enrolled), do: "Você já tem a programação toda."
  defp erro_do_pacote(:organizer), do: "Você organiza esta programação."
  defp erro_do_pacote(:no_package), do: "Esta programação não tem preço fechado."
  defp erro_do_pacote(_outro), do: "Não foi possível confirmar o pacote."

  defp alternar(selecionados, id) do
    case MapSet.member?(selecionados, id) do
      true -> MapSet.delete(selecionados, id)
      false -> MapSet.put(selecionados, id)
    end
  end

  defp tom(%{enrolled: []}), do: :error
  defp tom(_resultado), do: :info

  # Names what failed: "one did not work" says neither which nor why.
  defp resumo_do_lote(%{enrolled: [], failed: [{workshop, motivo} | _]}) do
    "#{workshop.title} não deu: #{motivo_do_erro(motivo)}"
  end

  defp resumo_do_lote(%{enrolled: inscritos, failed: []}) do
    "#{confirmadas(length(inscritos))} Te vejo lá."
  end

  defp resumo_do_lote(%{enrolled: inscritos, failed: [{workshop, motivo} | _]}) do
    "#{confirmadas(length(inscritos))} #{workshop.title} não deu: #{motivo_do_erro(motivo)}"
  end

  defp confirmadas(1), do: "1 inscrição confirmada."
  defp confirmadas(total), do: "#{total} inscrições confirmadas."

  defp motivo_do_erro(:full), do: "as vagas acabaram."
  defp motivo_do_erro(:not_open), do: "não está aberto para inscrição."
  defp motivo_do_erro(:organizer), do: "você organiza esse."
  defp motivo_do_erro(_outro), do: "não foi possível inscrever."

  # The id comes from params on a public page: only the organizer changes it, and
  # the real authorization lives in the context, which checks both sides.
  defp montar(%{assigns: %{owner?: false}} = socket, _id, _fun, _mensagem),
    do: {:noreply, socket}

  defp montar(socket, id, fun, mensagem) do
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
  def tom_do_pagamento(:paid), do: :green
  def tom_do_pagamento(:waived), do: :neutral
  def tom_do_pagamento(_pending), do: :orange

  @doc false
  def selecao_label(0), do: "Marque os workshops que você vai."
  def selecao_label(1), do: "1 workshop marcado."
  def selecao_label(total), do: "#{total} workshops marcados."

  @doc false
  def day_heading(date) do
    Brazil.strftime(date, "%A, %d de %B")
  end
end
