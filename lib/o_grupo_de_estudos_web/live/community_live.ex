defmodule OGrupoDeEstudosWeb.CommunityLive do
  @moduledoc """
  Community page — shows suggested steps and public sequences.

  Steps tabs: all | pending | approved.
  Sequences tab: all public sequences sorted by like count.
  Accessible to all authenticated users.
  """

  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Encyclopedia, Engagement, Sequences}

  on_mount {OGrupoDeEstudosWeb.UserAuth, :ensure_authenticated}
  on_mount {OGrupoDeEstudosWeb.Navigation, :primary}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.UI.BottomNav

  use OGrupoDeEstudosWeb.NotificationHandlers

  @impl true
  def mount(_params, _session, socket) do
    admin = Accounts.admin?(socket.assigns.current_user)
    steps = Encyclopedia.list_suggested_steps_filtered(filter: "all")

    {:ok,
     assign(socket,
       page_title: "Comunidade",
       is_admin: admin,
       active_section: "steps",
       active_tab: "all",
       steps: steps,
       sequences: [],
       sequence_likes: %{liked_ids: MapSet.new(), counts: %{}}
     )}
  end

  @impl true
  def handle_event("switch_section", %{"section" => "sequences"}, socket) do
    sequences = Sequences.list_all_public_sequences()

    sequence_ids = Enum.map(sequences, & &1.id)
    current_user = socket.assigns.current_user
    sequence_likes = Engagement.likes_map(current_user.id, "sequence", sequence_ids)

    sorted =
      Enum.sort_by(
        sequences,
        fn seq ->
          {-seq.like_count, seq.inserted_at}
        end
      )

    {:noreply,
     assign(socket,
       active_section: "sequences",
       sequences: sorted,
       sequence_likes: sequence_likes
     )}
  end

  def handle_event("switch_section", %{"section" => "steps"}, socket) do
    {:noreply, assign(socket, active_section: "steps")}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    steps = Encyclopedia.list_suggested_steps_filtered(filter: tab)
    {:noreply, assign(socket, active_tab: tab, steps: steps)}
  end

  def handle_event("toggle_like", %{"type" => "sequence", "id" => id}, socket) do
    current_user = socket.assigns.current_user

    case Engagement.toggle_like(current_user.id, "sequence", id) do
      {:ok, _action} ->
        sequences = socket.assigns.sequences
        sequence_ids = Enum.map(sequences, & &1.id)
        sequence_likes = Engagement.likes_map(current_user.id, "sequence", sequence_ids)

        sorted =
          Enum.sort_by(
            sequences,
            fn seq ->
              {-seq.like_count, seq.inserted_at}
            end
          )

        {:noreply, assign(socket, sequences: sorted, sequence_likes: sequence_likes)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível registrar o like.")}
    end
  end

  # Helpers

  def category_color(%{category: %{color: color}}), do: color
  def category_color(_), do: "#7f8c8d"

  def category_label(%{category: %{label: label}}), do: label
  def category_label(_), do: ""

  def connection_count(%{connections_as_source: conns_out, connections_as_target: conns_in}) do
    length(conns_out) + length(conns_in)
  end

  def connection_count(_), do: 0

  def youtube_embed_url(url) when is_binary(url) do
    cond do
      Regex.match?(~r/youtu\.be\/([a-zA-Z0-9_-]+)/, url) ->
        [_, id] = Regex.run(~r/youtu\.be\/([a-zA-Z0-9_-]+)/, url)
        {:embed, "https://www.youtube.com/embed/#{id}"}

      Regex.match?(~r/youtube\.com\/watch\?v=([a-zA-Z0-9_-]+)/, url) ->
        [_, id] = Regex.run(~r/youtube\.com\/watch\?v=([a-zA-Z0-9_-]+)/, url)
        {:embed, "https://www.youtube.com/embed/#{id}"}

      Regex.match?(~r/youtube\.com\/shorts\/([a-zA-Z0-9_-]+)/, url) ->
        [_, id] = Regex.run(~r/youtube\.com\/shorts\/([a-zA-Z0-9_-]+)/, url)
        {:embed, "https://www.youtube.com/embed/#{id}"}

      true ->
        :external
    end
  end

  def youtube_embed_url(_), do: :external
end
