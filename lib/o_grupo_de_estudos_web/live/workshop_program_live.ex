defmodule OGrupoDeEstudosWeb.WorkshopProgramLive do
  @moduledoc """
  Página pública da programação: o link único que vai para o WhatsApp.

  Mostra os workshops agrupados por dia, no fuso de quem dança, para a pessoa
  entender de uma olhada o que acontece na quinta e o que acontece na sexta.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Brazil, Workshops}
  alias OGrupoDeEstudos.Authorization.Policy

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
  def day_heading(date) do
    Brazil.strftime(date, "%A, %d de %B")
  end
end
