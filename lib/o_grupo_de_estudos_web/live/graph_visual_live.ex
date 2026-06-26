defmodule OGrupoDeEstudosWeb.GraphVisualLive do
  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Admin, Encyclopedia, Engagement, Sequences}
  alias OGrupoDeEstudos.Encyclopedia.StepQuery
  alias OGrupoDeEstudosWeb.GraphVisual.{GraphData, SequenceLibrary, TextSearch}

  on_mount {OGrupoDeEstudosWeb.Navigation, :primary}
  on_mount {OGrupoDeEstudosWeb.Hooks.NotificationSubscriber, :default}

  import OGrupoDeEstudosWeb.UI.TopNav
  import OGrupoDeEstudosWeb.UI.BottomNav
  import OGrupoDeEstudosWeb.UI.InlineFollowButton
  import OGrupoDeEstudosWeb.GraphVisual.SequenceSummary

  use OGrupoDeEstudosWeb.NotificationHandlers
  use OGrupoDeEstudosWeb.Handlers.FollowHandlers
  use OGrupoDeEstudosWeb.Handlers.ActivityToastHandlers
  use OGrupoDeEstudosWeb.Handlers.GraphSearch
  use OGrupoDeEstudosWeb.Handlers.GraphLikeFavorite
  use OGrupoDeEstudosWeb.Handlers.GraphPanel
  use OGrupoDeEstudosWeb.Handlers.GraphHighlight
  use OGrupoDeEstudosWeb.Handlers.GraphGenerator
  use OGrupoDeEstudosWeb.Handlers.GraphSequenceLibrary
  use OGrupoDeEstudosWeb.Handlers.GraphAdminEdits
  use OGrupoDeEstudosWeb.Handlers.GraphManualDraft
  use OGrupoDeEstudosWeb.Handlers.GraphManualSteps

  import OGrupoDeEstudosWeb.UI.ActivityToast

  @graph_legend_hidden_categories ~w(convencoes footwork)

  @impl true
  def mount(_params, _session, socket) do
    is_admin = Accounts.admin?(socket.assigns.current_user)

    socket =
      socket
      |> assign(:page_title, "Mapa de Passos")
      |> assign(:loaded?, false)
      |> assign(:is_admin, is_admin)
      |> assign(:edit_mode, false)
      |> assign(:seq_panel, true)
      |> assign(:seq_mobile_visible, false)
      |> assign(:seq_view, :library)
      |> assign(:seq_results, [])
      |> assign(:seq_warnings, [])
      |> assign(:seq_saved, [])
      |> assign(:seq_library, [])
      |> assign(:seq_library_all, [])
      |> assign(:seq_library_search, "")
      |> assign(:seq_library_origin_filter, "all")
      |> assign(:seq_library_category_filter, "all")
      |> assign(:seq_owned_ids, MapSet.new())
      |> assign(:seq_favorite_ids, MapSet.new())
      |> assign(:seq_active, nil)
      |> assign(:seq_active_id, nil)
      |> assign(:seq_initial_steps_json, "[]")
      |> assign(:seq_saving, nil)
      |> assign(:seq_start_code, "BF")
      |> assign(:seq_start_query, "BF")
      |> assign(:seq_start_suggestions, [])
      |> assign(:seq_required_codes, [])
      |> assign(:seq_required_search, "")
      |> assign(:seq_required_suggestions, [])
      |> assign(:graph_search_query, "")
      |> assign(:graph_search_results, [])
      |> assign(:graph_json, ~s({"nodes":[],"edges":[]}))
      |> assign(:graph_search_nodes, [])
      |> assign(:categories, [])
      |> assign(:edges, [])
      |> assign(:seq_manual_steps, [])
      |> assign(:seq_manual_error, nil)
      |> assign(:seq_manual_search, "")
      |> assign(:seq_manual_suggestions, [])
      |> assign(:seq_manual_favorite_steps, [])
      |> assign(:seq_editing_id, nil)
      |> assign(:seq_manual_name, "")
      |> assign(:seq_manual_description, "")
      |> assign(:seq_manual_video_url, "")
      |> assign(:seq_missing_edges, [])
      |> assign(:seq_suggested_edges, MapSet.new())
      |> assign(:seq_favorites_list, [])
      |> assign(:liked_step_codes, [])
      |> assign(:following_user_ids, MapSet.new())
      |> assign(:bubble_open, false)
      |> assign(:bubble_tab, "following")
      |> assign(:bubble_following_list, [])
      |> assign(:bubble_followers_list, [])
      |> assign(:bubble_search, "")
      |> assign(:bubble_search_results, [])
      |> assign(:suggested_users, [])
      |> load_graph_data()

    {:ok, socket}
  end

  # Iron Law: o grafo e a biblioteca de sequências (queries pesadas) só rodam
  # no render conectado. O dead/HTTP render volta instantâneo com placeholders
  # + skeleton sobre o canvas; o mount conectado constrói o grafo (o hook
  # Cytoscape lê data-graph no connect).
  defp load_graph_data(socket) do
    if connected?(socket) do
      user_id = socket.assigns.current_user.id
      graph = Encyclopedia.build_graph()
      liked_codes = Engagement.liked_step_codes(user_id)

      socket
      |> assign(:loaded?, true)
      |> assign(:liked_step_codes, liked_codes)
      |> assign(:following_user_ids, Engagement.following_ids(user_id))
      |> assign_graph_data(graph, false)
      |> assign_default_sequence_start()
      |> assign_manual_favorite_steps()
      |> assign_sequence_library()
      |> push_event("set_liked_steps", %{codes: liked_codes})
      |> push_event("set_favorited_steps", %{codes: favorited_step_codes(user_id)})
    else
      socket
    end
  end

  @impl true
  def handle_params(%{"mode" => "generator"}, _uri, socket) do
    {:noreply,
     socket
     |> assign(:seq_panel, true)
     |> assign(:seq_mobile_visible, true)
     |> assign(:seq_view, :config)
     |> assign(:seq_results, [])
     |> assign(:seq_warnings, [])
     |> assign(:seq_saving, nil)
     |> deactivate_manual_mode()}
  end

  def handle_params(%{"mode" => "manual"}, _uri, socket) do
    {:noreply,
     socket
     |> assign(:seq_panel, true)
     |> assign(:seq_mobile_visible, true)
     |> assign(:seq_view, :manual)
     |> assign(:seq_manual_steps, [])
     |> assign(:seq_manual_error, nil)
     |> assign(:seq_manual_search, "")
     |> assign(:seq_manual_suggestions, [])
     |> assign(:editing_sequence_id, nil)
     |> assign(:seq_manual_name, "")
     |> assign(:seq_manual_description, "")
     |> assign(:seq_manual_video_url, "")
     |> assign(:seq_results, [])
     |> assign(:seq_warnings, [])
     |> assign(:seq_saving, nil)
     |> assign_manual_favorite_steps()
     |> push_event("set_manual_mode", %{active: true})}
  end

  def handle_params(%{"seq" => seq_id}, _uri, socket) do
    case Sequences.get_sequence(seq_id) do
      nil ->
        {:noreply, socket}

      saved ->
        steps = Enum.sort_by(saved.sequence_steps, & &1.position)
        step_codes = Enum.map(steps, & &1.step.code)
        step_list = Enum.map(steps, &%{id: &1.step.id, code: &1.step.code, name: &1.step.name})

        {:noreply,
         socket
         |> assign(:seq_active, step_list)
         |> assign(:seq_active_id, saved.id)
         |> assign(:seq_initial_steps_json, Jason.encode!(step_codes))
         |> assign(:seq_missing_edges, [])
         |> assign(:seq_panel, true)
         |> assign(:seq_mobile_visible, false)
         |> assign(:seq_view, :library)
         |> push_event("highlight_sequence", %{steps: step_codes})}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  defp favorited_step_codes(user_id) do
    import Ecto.Query

    from(f in OGrupoDeEstudos.Engagement.Favorite,
      where: f.user_id == ^user_id and f.favoritable_type == "step",
      join: s in OGrupoDeEstudos.Encyclopedia.Step,
      on: s.id == f.favoritable_id,
      select: s.code
    )
    |> OGrupoDeEstudos.Repo.all()
  end

  defp can_manage_sequence?(_socket, nil), do: false

  defp can_manage_sequence?(socket, sequence) do
    socket.assigns.is_admin or sequence.user_id == socket.assigns.current_user.id
  end

  defp do_create_missing_connection(socket, src_code, tgt_code) do
    source = StepQuery.get_by(code: src_code)
    target = StepQuery.get_by(code: tgt_code)

    if source && target do
      Admin.create_connection(%{source_step_id: source.id, target_step_id: target.id})

      graph = Encyclopedia.build_graph()

      step_codes =
        if socket.assigns.seq_active,
          do: Enum.map(socket.assigns.seq_active, & &1.code),
          else: []

      missing =
        if step_codes != [], do: GraphData.find_missing_edges(step_codes, graph.edges), else: []

      {:noreply,
       socket
       |> assign(:edges, graph.edges)
       |> assign(:seq_missing_edges, missing)
       |> put_flash(:info, "Conexão #{src_code} → #{tgt_code} criada!")}
    else
      {:noreply, put_flash(socket, :error, "Passos não encontrados")}
    end
  end

  defp do_save_manual_sequence(socket, name, description, video_url, manual_steps, user_id) do
    step_codes = Enum.map(manual_steps, & &1.code)

    attrs = %{
      name: name,
      step_codes: step_codes,
      description: if(description == "", do: nil, else: description),
      video_url: if(video_url == "", do: nil, else: video_url)
    }

    result = persist_manual_sequence(socket, user_id, attrs)

    case result do
      {:ok, _saved} ->
        {:noreply,
         socket
         |> assign(:seq_manual_steps, [])
         |> assign(:seq_manual_error, nil)
         |> assign(:seq_manual_search, "")
         |> assign(:seq_manual_suggestions, [])
         |> assign(:seq_editing_id, nil)
         |> assign(:seq_manual_name, "")
         |> assign(:seq_manual_description, "")
         |> assign(:seq_manual_video_url, "")
         |> assign(:seq_view, :library)
         |> assign_sequence_library()
         |> push_event("set_manual_mode", %{active: false})}

      {:error, :invalid_codes} ->
        {:noreply, assign(socket, :seq_manual_error, "Código de passo inválido.")}

      {:error, :unauthorized} ->
        {:noreply, assign(socket, :seq_manual_error, "Você não pode editar esta sequência.")}

      {:error, changeset} ->
        msg =
          Enum.map_join(changeset.errors, ", ", fn {field, {msg, _}} ->
            "#{field}: #{msg}"
          end)

        {:noreply, assign(socket, :seq_manual_error, msg)}
    end
  end

  defp persist_manual_sequence(socket, user_id, attrs) do
    case socket.assigns.seq_editing_id do
      nil ->
        Sequences.create_manual_sequence(user_id, attrs)

      sequence_id ->
        sequence = Sequences.get_sequence(sequence_id)

        if can_manage_sequence?(socket, sequence) do
          Sequences.update_manual_sequence(sequence, attrs)
        else
          {:error, :unauthorized}
        end
    end
  end

  defp append_manual_step(socket, %{code: code, name: name}) do
    step = %{code: code, name: name}
    new_steps = socket.assigns.seq_manual_steps ++ [step]

    socket
    |> assign(:seq_manual_steps, new_steps)
    |> assign(:seq_manual_error, nil)
    |> recompute_manual_missing_edges(new_steps)
    |> push_event("highlight_sequence", %{steps: Enum.map(new_steps, & &1.code)})
  end

  defp manual_step_suggestions(_socket, ""), do: []

  defp manual_step_suggestions(socket, term) do
    socket.assigns.graph_search_nodes
    |> GraphData.search_graph_nodes(term)
    |> Enum.take(6)
  end

  defp find_manual_step(_socket, ""), do: nil

  defp find_manual_step(socket, term) do
    normalized_term = TextSearch.normalize(term)

    exact =
      Enum.find(socket.assigns.graph_search_nodes, fn step ->
        TextSearch.normalize(step.code) == normalized_term or
          TextSearch.normalize(step.name) == normalized_term
      end)

    step = exact || List.first(manual_step_suggestions(socket, term))

    if step do
      %{code: step.code, name: step.name}
    end
  end

  defp valid_index?(steps, index), do: index >= 0 and index < length(steps)

  defp parse_index(value) when is_binary(value) do
    case Integer.parse(value) do
      {index, ""} when index >= 0 -> index
      _ -> -1
    end
  end

  defp parse_index(value) when is_integer(value) and value >= 0, do: value
  defp parse_index(_value), do: -1

  defp reset_manual_draft(socket) do
    socket
    |> assign(:seq_manual_steps, [])
    |> assign(:seq_manual_error, nil)
    |> assign(:seq_manual_search, "")
    |> assign(:seq_manual_suggestions, [])
    |> assign(:seq_editing_id, nil)
    |> assign(:seq_manual_name, "")
    |> assign(:seq_manual_description, "")
    |> assign(:seq_manual_video_url, "")
  end

  defp deactivate_manual_mode(socket) do
    socket
    |> assign(:seq_manual_search, "")
    |> assign(:seq_manual_suggestions, [])
    |> push_event("set_manual_mode", %{active: false})
  end

  defp assign_manual_favorite_steps(socket) do
    visible_by_code =
      socket.assigns.graph_search_nodes
      |> Map.new(&{&1.code, &1})

    favorite_steps =
      socket.assigns.current_user.id
      |> Engagement.list_user_favorites("step")
      |> Enum.filter(&Map.has_key?(visible_by_code, &1.code))
      |> Enum.map(fn step ->
        visible = Map.fetch!(visible_by_code, step.code)
        %{code: visible.code, name: visible.name, category: visible.category}
      end)
      |> Enum.take(8)

    assign(socket, :seq_manual_favorite_steps, favorite_steps)
  end

  defp assign_default_sequence_start(socket) do
    code = socket.assigns.seq_start_code

    assign(socket, :seq_start_query, step_display_label(code, socket.assigns.graph_search_nodes))
  end

  defp maybe_clear_deleted_sequence(socket, sequence_id) do
    active? = socket.assigns.seq_active_id == sequence_id
    editing? = socket.assigns.seq_editing_id == sequence_id

    if active? or editing? do
      socket
      |> assign(:seq_active, nil)
      |> assign(:seq_active_id, nil)
      |> assign(:seq_missing_edges, [])
      |> assign(:seq_view, :library)
      |> assign(:seq_manual_steps, [])
      |> assign(:seq_manual_error, nil)
      |> assign(:seq_editing_id, nil)
      |> assign(:seq_manual_name, "")
      |> assign(:seq_manual_description, "")
      |> assign(:seq_manual_video_url, "")
      |> push_event("clear_highlight", %{})
      |> push_event("set_manual_mode", %{active: false})
    else
      socket
    end
  end

  defp assign_sequence_library(socket) do
    user_id = socket.assigns.current_user.id
    saved = Sequences.list_user_sequences(user_id)
    favorites = Engagement.list_user_favorites(user_id, "sequence")
    public = Sequences.list_all_public_sequences()

    all =
      (saved ++ favorites ++ public)
      |> Enum.uniq_by(& &1.id)

    owned_ids = saved |> Enum.map(& &1.id) |> MapSet.new()
    all_ids = Enum.map(all, & &1.id)
    favorite_ids = Engagement.favorites_map(user_id, "sequence", all_ids)

    all =
      Enum.sort_by(all, fn sequence ->
        {
          SequenceLibrary.sequence_library_rank(sequence, owned_ids, favorite_ids),
          -Map.get(sequence, :like_count, 0),
          SequenceLibrary.normalize_sequence_date(sequence.inserted_at),
          TextSearch.normalize(sequence.name)
        }
      end)

    socket
    |> assign(:seq_saved, saved)
    |> assign(:seq_favorites_list, favorites)
    |> assign(:seq_library_all, all)
    |> assign(:seq_owned_ids, owned_ids)
    |> assign(:seq_favorite_ids, favorite_ids)
    |> assign_filtered_sequence_library()
  end

  defp assign_filtered_sequence_library(socket) do
    filtered =
      SequenceLibrary.filter_sequence_library(
        socket.assigns.seq_library_all,
        socket.assigns.seq_library_search,
        socket.assigns.seq_library_origin_filter,
        socket.assigns.seq_library_category_filter,
        socket.assigns.seq_owned_ids,
        socket.assigns.seq_favorite_ids
      )

    assign(socket, :seq_library, filtered)
  end

  defp graph_legend_categories(categories) do
    Enum.reject(categories, &(&1.name in @graph_legend_hidden_categories))
  end

  defp assign_graph_data(socket, graph, include_orphans) do
    graph_json = GraphData.build_json(graph, include_orphans)

    connected_codes =
      graph.edges
      |> Enum.flat_map(&[&1.source_step.code, &1.target_step.code])
      |> MapSet.new()

    graph_search_nodes =
      graph.nodes
      |> Enum.filter(&(include_orphans or MapSet.member?(connected_codes, &1.code)))
      |> Enum.map(fn step ->
        %{
          code: step.code,
          name: step.name,
          category: if(step.category, do: step.category.label, else: "Outros")
        }
      end)

    categories =
      graph.nodes
      |> Enum.map(& &1.category)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(& &1.id)
      |> Enum.sort_by(& &1.label)

    socket
    |> assign(:graph_json, graph_json)
    |> assign(:graph_search_nodes, graph_search_nodes)
    |> assign(:categories, categories)
    |> assign(:edges, graph.edges)
  end

  defp recompute_manual_missing_edges(socket, manual_steps) do
    step_codes = Enum.map(manual_steps, & &1.code)
    edges = Map.get(socket.assigns, :edges, [])
    assign(socket, :seq_missing_edges, GraphData.find_missing_edges(step_codes, edges))
  end

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} when n > 0 -> n
      _ -> default
    end
  end

  defp parse_int(val, _default) when is_integer(val) and val > 0, do: val
  defp parse_int(_val, default), do: default
end
