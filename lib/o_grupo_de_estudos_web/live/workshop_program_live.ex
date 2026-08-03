defmodule OGrupoDeEstudosWeb.WorkshopProgramLive do
  @moduledoc """
  Página pública da programação: o link único que vai para o WhatsApp.

  Mostra os workshops agrupados por dia, no fuso de quem dança, para a pessoa
  entender de uma olhada o que acontece na quinta e o que acontece na sexta.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Brazil, Workshops}
  alias OGrupoDeEstudos.Authorization.Policy
  alias OGrupoDeEstudos.Workshops.Workshop

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
  end

  # So oferece checkbox no que da para se inscrever agora: publicado, com vaga
  # e onde a pessoa ainda nao esta.
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

  # Painel de montagem: so para quem organiza, e so com o que ele administra.
  defp assign_montagem(socket, _workshops, false, _user) do
    socket |> assign(:dentro, []) |> assign(:disponiveis, [])
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

  defp alternar(selecionados, id) do
    case MapSet.member?(selecionados, id) do
      true -> MapSet.delete(selecionados, id)
      false -> MapSet.put(selecionados, id)
    end
  end

  defp tom(%{enrolled: []}), do: :error
  defp tom(_resultado), do: :info

  # Nomeia o que falhou: "nao deu em uma" nao diz qual nem por que.
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

  # Id vem de params numa pagina publica: so quem organiza mexe, e a
  # autorizacao real mora no contexto, que confere os dois lados.
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

  # Agrupa pelo dia LOCAL: um workshop das 20h de quinta em Brasilia e 23h UTC
  # da quinta, mas um das 22h ja seria sexta em UTC e apareceria no dia errado.
  defp group_by_day(workshops) do
    workshops
    |> Enum.group_by(&(&1.starts_at |> Brazil.to_local() |> DateTime.to_date()))
    |> Enum.sort_by(fn {date, _} -> date end, Date)
  end

  @doc false
  def selecao_label(0), do: "Marque os workshops que você vai."
  def selecao_label(1), do: "1 workshop marcado."
  def selecao_label(total), do: "#{total} workshops marcados."

  @doc false
  def day_heading(date) do
    Brazil.strftime(date, "%A, %d de %B")
  end
end
