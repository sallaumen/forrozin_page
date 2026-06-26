defmodule OGrupoDeEstudosWeb.GraphVisualLive do
  use OGrupoDeEstudosWeb, :live_view

  alias OGrupoDeEstudos.{Accounts, Admin, Encyclopedia, Engagement, Media, Sequences}
  alias OGrupoDeEstudos.Encyclopedia.{ConnectionQuery, StepQuery}
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
  use OGrupoDeEstudosWeb.Handlers.GraphThreeD
  use OGrupoDeEstudosWeb.Handlers.GraphSearch
  use OGrupoDeEstudosWeb.Handlers.GraphLikeFavorite
  use OGrupoDeEstudosWeb.Handlers.GraphPanel

  import OGrupoDeEstudosWeb.UI.ActivityToast

  @graph_legend_hidden_categories ~w(convencoes footwork)

  @impl true
  def mount(_params, _session, socket) do
    is_admin = Accounts.admin?(socket.assigns.current_user)
    can_3d = socket.assigns.current_user.username == "tata"

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
      |> assign(:can_3d, can_3d)
      |> assign(:three_d_mode, false)
      |> assign(:three_d_steps, [])
      |> assign(:three_d_current_step, 0)
      |> assign(:three_d_playing, false)
      |> assign(:three_d_speed, 1.0)
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

  @impl true
  def handle_event("generate_sequences", params, socket) do
    start_code =
      params
      |> Map.get("start_query", Map.get(params, "start_code", ""))
      |> resolve_step_code(socket.assigns.graph_search_nodes, Map.get(params, "start_code", ""))

    loop_mode = Map.get(params, "loop_mode", "none")

    allow_repeats =
      loop_mode in ["light", "free"] or Map.get(params, "allow_repeats") in ["true", "on"]

    cyclic = Map.get(params, "cyclic") in ["true", "on"]
    min_length = if allow_repeats, do: 8, else: 4
    length_val = parse_int(Map.get(params, "length", "10"), 10) |> max(min_length)
    count_val = parse_int(Map.get(params, "count", "3"), 3)

    required_codes = socket.assigns.seq_required_codes

    max_bf = parse_int(Map.get(params, "max_bf_visits", "3"), 3)

    gen_params = %{
      start_code: start_code,
      length: length_val,
      count: count_val,
      required_codes: required_codes,
      allow_repeats: allow_repeats,
      cyclic: cyclic,
      max_bf_visits: max_bf,
      max_same_pair_loops: max_same_pair_loops(loop_mode)
    }

    {:ok, sequences, warnings} = Sequences.generate(gen_params)

    {:noreply,
     socket
     |> assign(:seq_results, sequences)
     |> assign(:seq_warnings, warnings)
     |> assign(:seq_view, :results)
     |> assign(:seq_saving, nil)
     |> assign(:seq_missing_edges, [])}
  end

  def handle_event("highlight_sequence", %{"index" => index_str}, socket) do
    index = parse_int(index_str, 0)
    sequence = Enum.at(socket.assigns.seq_results, index)

    if sequence do
      step_codes = Enum.map(sequence, & &1.code)

      {:noreply,
       socket
       |> assign(:seq_active, sequence)
       |> assign(:seq_active_id, nil)
       |> assign(:seq_initial_steps_json, "[]")
       |> assign(:seq_mobile_visible, false)
       |> push_event("highlight_sequence", %{steps: step_codes})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("highlight_saved_sequence", %{"id" => id} = params, socket) do
    saved = Sequences.get_sequence(id)

    if saved do
      steps = Enum.sort_by(saved.sequence_steps, & &1.position)
      step_codes = Enum.map(steps, & &1.step.code)
      step_list = Enum.map(steps, &%{id: &1.step.id, code: &1.step.code, name: &1.step.name})

      socket =
        socket
        |> assign(:seq_active, step_list)
        |> assign(:seq_active_id, saved.id)
        |> assign(:seq_initial_steps_json, Jason.encode!(step_codes))
        |> assign(:seq_missing_edges, [])
        |> assign(:seq_mobile_visible, false)
        |> push_event("highlight_sequence", %{steps: step_codes})

      # If "then_3d" param is set, enter 3D mode after highlighting
      socket =
        if params["then_3d"] == "true" do
          loaded_steps =
            step_codes
            |> Enum.map(&StepQuery.get_by(code: &1))
            |> Enum.reject(&is_nil/1)
            |> OGrupoDeEstudos.Repo.preload(:category)

          animation_data = Media.build_sequence_animation(loaded_steps)

          socket
          |> assign(:three_d_mode, true)
          |> assign(:three_d_steps, animation_data)
          |> assign(:three_d_current_step, 0)
          |> assign(:three_d_playing, true)
          |> push_event("load_animation", %{steps: animation_data})
        else
          socket
        end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("edit_saved_sequence", %{"id" => id}, socket) do
    saved = Sequences.get_sequence(id)

    if can_manage_sequence?(socket, saved) do
      steps = Enum.sort_by(saved.sequence_steps, & &1.position)
      manual_steps = Enum.map(steps, &%{code: &1.step.code, name: &1.step.name})

      {:noreply,
       socket
       |> assign(:seq_view, :manual)
       |> assign(:seq_manual_steps, manual_steps)
       |> assign(:seq_manual_error, nil)
       |> assign(:seq_manual_search, "")
       |> assign(:seq_manual_suggestions, [])
       |> assign(:seq_editing_id, saved.id)
       |> assign(:seq_manual_name, saved.name || "")
       |> assign(:seq_manual_description, saved.description || "")
       |> assign(:seq_manual_video_url, saved.video_url || "")
       |> recompute_manual_missing_edges(manual_steps)
       |> push_event("set_manual_mode", %{active: true})
       |> push_event("highlight_sequence", %{steps: Enum.map(manual_steps, & &1.code)})}
    else
      {:noreply, socket}
    end
  end

  def handle_event(
        "create_missing_connection",
        %{"source" => src_code, "target" => tgt_code},
        socket
      ) do
    if socket.assigns.is_admin do
      do_create_missing_connection(socket, src_code, tgt_code)
    else
      {:noreply, socket}
    end
  end

  def handle_event(
        "suggest_missing_connection",
        %{"source" => src_code, "target" => tgt_code},
        socket
      ) do
    user = socket.assigns.current_user
    source = StepQuery.get_by(code: src_code)

    if source do
      case OGrupoDeEstudos.Suggestions.create(user, %{
             target_type: "connection",
             target_id: source.id,
             action: "create_connection",
             new_value: "#{src_code}\u2192#{tgt_code}"
           }) do
        {:ok, _} ->
          suggested = MapSet.put(socket.assigns.seq_suggested_edges, {src_code, tgt_code})

          {:noreply,
           socket
           |> assign(:seq_suggested_edges, suggested)
           |> put_flash(
             :info,
             "Sugestao enviada! A conexao #{src_code} -> #{tgt_code} sera revisada em 1-2 dias. Obrigado pelo feedback!"
           )}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Erro ao enviar sugestao")}
      end
    else
      {:noreply, put_flash(socket, :error, "Passo nao encontrado")}
    end
  end

  def handle_event("clear_highlight", _params, socket) do
    {:noreply,
     socket
     |> assign(:seq_active, nil)
     |> assign(:seq_active_id, nil)
     |> assign(:seq_initial_steps_json, "[]")
     |> assign(:seq_missing_edges, [])
     |> push_event("clear_highlight", %{})}
  end

  def handle_event("start_save_sequence", %{"index" => index_str}, socket) do
    index = parse_int(index_str, 0)
    {:noreply, assign(socket, :seq_saving, index)}
  end

  def handle_event("cancel_save_sequence", _params, socket) do
    {:noreply, assign(socket, :seq_saving, nil)}
  end

  def handle_event("save_sequence", %{"index" => index_str, "name" => name}, socket) do
    index = parse_int(index_str, 0)
    sequence = Enum.at(socket.assigns.seq_results, index)
    name = String.trim(name)

    if sequence && name != "" do
      step_ids = Enum.map(sequence, & &1.id)
      user_id = socket.assigns.current_user.id

      case Sequences.create_sequence(user_id, name, step_ids) do
        {:ok, _saved} ->
          {:noreply,
           socket
           |> assign(:seq_saving, nil)
           |> assign_sequence_library()}

        {:error, _changeset} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_sequence", %{"id" => id}, socket) do
    sequence = Sequences.get_sequence(id)

    if can_manage_sequence?(socket, sequence) do
      {:ok, _} = Sequences.delete_sequence(sequence)

      socket =
        socket
        |> assign_sequence_library()
        |> maybe_clear_deleted_sequence(id)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("show_seq_config", _params, socket) do
    {:noreply,
     socket
     |> assign(:seq_view, :config)
     |> assign(:seq_results, [])
     |> assign(:seq_warnings, [])
     |> assign(:seq_saving, nil)
     |> deactivate_manual_mode()}
  end

  def handle_event("show_seq_library", _params, socket) do
    {:noreply,
     socket
     |> assign(:seq_view, :library)
     |> assign_sequence_library()
     |> deactivate_manual_mode()}
  end

  def handle_event("show_seq_saved", _params, socket) do
    {:noreply,
     socket
     |> assign(:seq_view, :library)
     |> assign_sequence_library()
     |> deactivate_manual_mode()}
  end

  def handle_event("show_seq_favorites", _params, socket) do
    {:noreply,
     socket
     |> assign(:seq_view, :library)
     |> assign_sequence_library()
     |> deactivate_manual_mode()}
  end

  def handle_event("search_sequence_library", params, socket) do
    term = params["value"] || params["term"] || ""

    {:noreply,
     socket
     |> assign(:seq_library_search, term)
     |> assign_filtered_sequence_library()}
  end

  def handle_event("filter_sequence_library_origin", %{"origin" => origin}, socket) do
    {:noreply,
     socket
     |> assign(:seq_library_origin_filter, origin)
     |> assign_filtered_sequence_library()}
  end

  def handle_event("filter_sequence_library_category", %{"category" => category}, socket) do
    {:noreply,
     socket
     |> assign(:seq_library_category_filter, category)
     |> assign_filtered_sequence_library()}
  end

  def handle_event("toggle_sequence_favorite_graph", %{"id" => seq_id}, socket) do
    user_id = socket.assigns.current_user.id

    case Engagement.toggle_favorite(user_id, "sequence", seq_id) do
      {:ok, _} ->
        {:noreply, assign_sequence_library(socket)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  def handle_event("show_seq_manual", _params, socket) do
    {:noreply,
     socket
     |> assign(:seq_view, :manual)
     |> assign(:seq_manual_steps, [])
     |> assign(:seq_manual_error, nil)
     |> assign(:seq_manual_search, "")
     |> assign(:seq_manual_suggestions, [])
     |> assign(:seq_editing_id, nil)
     |> assign(:seq_manual_name, "")
     |> assign(:seq_manual_description, "")
     |> assign(:seq_manual_video_url, "")
     |> assign(:seq_missing_edges, [])
     |> assign_manual_favorite_steps()
     |> push_event("set_manual_mode", %{active: true})}
  end

  def handle_event("add_manual_step", %{"code" => code, "name" => name}, socket) do
    {:noreply, append_manual_step(socket, %{code: code, name: name})}
  end

  def handle_event("search_manual_step", params, socket) do
    term = String.trim(params["value"] || params["manual_step_search"] || "")
    suggestions = manual_step_suggestions(socket, term)

    {:noreply,
     socket
     |> assign(:seq_manual_search, term)
     |> assign(:seq_manual_suggestions, suggestions)}
  end

  def handle_event("add_manual_step_by_search", params, socket) do
    term = String.trim(params["manual_step_search"] || socket.assigns.seq_manual_search || "")

    case find_manual_step(socket, term) do
      nil ->
        {:noreply,
         socket
         |> assign(:seq_manual_search, term)
         |> assign(:seq_manual_suggestions, manual_step_suggestions(socket, term))
         |> assign(:seq_manual_error, "Escolha um passo da lista para adicionar.")}

      step ->
        {:noreply,
         socket
         |> append_manual_step(step)
         |> assign(:seq_manual_search, "")
         |> assign(:seq_manual_suggestions, [])}
    end
  end

  def handle_event("select_manual_step", %{"code" => code} = params, socket) do
    step =
      case Enum.find(socket.assigns.graph_search_nodes, &(&1.code == code)) do
        nil -> %{code: code, name: params["name"] || code}
        found -> %{code: found.code, name: found.name}
      end

    {:noreply,
     socket
     |> append_manual_step(step)
     |> assign(:seq_manual_search, "")
     |> assign(:seq_manual_suggestions, [])}
  end

  def handle_event("clear_manual_step_search", _params, socket) do
    {:noreply, assign(socket, seq_manual_search: "", seq_manual_suggestions: [])}
  end

  def handle_event("cancel_manual_sequence", _params, socket) do
    {:noreply,
     socket
     |> reset_manual_draft()
     |> assign(:seq_view, :library)
     |> assign_sequence_library()
     |> push_event("set_manual_mode", %{active: false})
     |> push_event("clear_highlight", %{})}
  end

  def handle_event("remove_manual_step", %{"index" => index_str}, socket) do
    index = parse_index(index_str)

    if valid_index?(socket.assigns.seq_manual_steps, index) do
      new_steps = List.delete_at(socket.assigns.seq_manual_steps, index)

      {:noreply,
       socket
       |> assign(:seq_manual_steps, new_steps)
       |> assign(:seq_manual_error, nil)
       |> recompute_manual_missing_edges(new_steps)
       |> push_event("highlight_sequence", %{steps: Enum.map(new_steps, & &1.code)})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("move_manual_step", %{"index" => index_str, "direction" => dir}, socket) do
    index = parse_index(index_str)
    steps = socket.assigns.seq_manual_steps
    new_index = if dir == "up", do: index - 1, else: index + 1

    if index >= 0 and new_index >= 0 and new_index < length(steps) do
      item = Enum.at(steps, index)
      new_steps = steps |> List.delete_at(index) |> List.insert_at(new_index, item)

      {:noreply,
       socket
       |> assign(:seq_manual_steps, new_steps)
       |> recompute_manual_missing_edges(new_steps)
       |> push_event("highlight_sequence", %{steps: Enum.map(new_steps, & &1.code)})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("save_manual_sequence", params, socket) do
    name = Map.get(params, "name", "") |> String.trim()
    description = Map.get(params, "description", "") |> String.trim()
    video_url = Map.get(params, "video_url", "") |> String.trim()
    manual_steps = socket.assigns.seq_manual_steps
    user_id = socket.assigns.current_user.id

    socket =
      socket
      |> assign(:seq_manual_name, name)
      |> assign(:seq_manual_description, description)
      |> assign(:seq_manual_video_url, video_url)

    cond do
      name == "" ->
        {:noreply, assign(socket, :seq_manual_error, "Nome é obrigatório.")}

      manual_steps == [] ->
        {:noreply, assign(socket, :seq_manual_error, "Adicione ao menos um passo.")}

      true ->
        do_save_manual_sequence(socket, name, description, video_url, manual_steps, user_id)
    end
  end

  # Autocomplete — start step
  def handle_event("search_start_step", %{"value" => term}, socket) do
    suggestions =
      if String.length(term) >= 1 do
        StepQuery.list_by(search: term, public_only: true, limit: 6, order_by: [asc: :code])
        |> Enum.map(&%{code: &1.code, name: &1.name})
      else
        []
      end

    {:noreply,
     socket
     |> assign(:seq_start_query, term)
     |> assign(:seq_start_suggestions, suggestions)}
  end

  def handle_event("select_start_step", %{"code" => code, "name" => name}, socket) do
    label = step_display_label(%{code: code, name: name})

    {:noreply,
     socket
     |> assign(:seq_start_code, code)
     |> assign(:seq_start_query, label)
     |> assign(:seq_start_suggestions, [])
     |> push_event("set_start_step_input", %{value: label, name: name})}
  end

  # Autocomplete — required steps
  def handle_event("search_required_step", %{"value" => term}, socket) do
    suggestions =
      if String.length(term) >= 1 do
        already = socket.assigns.seq_required_codes

        StepQuery.list_by(search: term, public_only: true, limit: 6, order_by: [asc: :code])
        |> Enum.reject(&(&1.code in already))
        |> Enum.map(&%{code: &1.code, name: &1.name})
      else
        []
      end

    {:noreply,
     socket
     |> assign(:seq_required_search, term)
     |> assign(:seq_required_suggestions, suggestions)}
  end

  def handle_event("select_required_step", %{"code" => code}, socket) do
    already = socket.assigns.seq_required_codes

    new_required =
      if code in already do
        already
      else
        already ++ [code]
      end

    {:noreply,
     socket
     |> assign(:seq_required_codes, new_required)
     |> assign(:seq_required_search, "")
     |> assign(:seq_required_suggestions, [])
     |> push_event("clear_required_input", %{})}
  end

  def handle_event("hide_seq_suggestions", _params, socket) do
    {:noreply,
     assign(socket,
       seq_start_suggestions: [],
       seq_required_suggestions: []
     )}
  end

  def handle_event("remove_required_step", %{"code" => code}, socket) do
    new_required = Enum.reject(socket.assigns.seq_required_codes, &(&1 == code))
    {:noreply, assign(socket, :seq_required_codes, new_required)}
  end

  def handle_event("toggle_edit_mode", _params, socket) do
    if socket.assigns.is_admin do
      new_mode = not socket.assigns.edit_mode
      graph = Encyclopedia.build_graph()

      socket =
        socket
        |> assign(:edit_mode, new_mode)
        |> assign_graph_data(graph, new_mode)

      {:noreply,
       push_event(socket, "graph_updated", %{
         graph_json: socket.assigns.graph_json,
         edit_mode: new_mode,
         orphans: if(new_mode, do: GraphData.build_orphans_json(graph), else: "[]")
       })}
    else
      {:noreply, socket}
    end
  end

  def handle_event(
        "create_connection",
        %{"source" => source_code, "target" => target_code},
        socket
      ) do
    if socket.assigns.is_admin do
      with source when not is_nil(source) <- StepQuery.get_by(code: source_code),
           target when not is_nil(target) <- StepQuery.get_by(code: target_code),
           {:ok, _conn} <-
             Admin.create_connection(%{source_step_id: source.id, target_step_id: target.id}) do
        graph = Encyclopedia.build_graph()
        edit_mode = socket.assigns.edit_mode

        socket =
          socket
          |> assign_graph_data(graph, edit_mode)

        {:noreply,
         push_event(socket, "graph_updated", %{
           graph_json: socket.assigns.graph_json,
           edit_mode: edit_mode,
           orphans: if(edit_mode, do: GraphData.build_orphans_json(graph), else: "[]")
         })}
      else
        {:error, _changeset} ->
          {:noreply, push_event(socket, "graph_error", %{message: "Conexão já existe"})}

        nil ->
          {:noreply, push_event(socket, "graph_error", %{message: "Passo não encontrado"})}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event(
        "delete_connection",
        %{"source" => source_code, "target" => target_code},
        socket
      ) do
    if socket.assigns.is_admin do
      connection = ConnectionQuery.get_by(source_code: source_code, target_code: target_code)

      case connection do
        nil ->
          {:noreply, push_event(socket, "graph_error", %{message: "Conexão não encontrada"})}

        conn ->
          {:ok, _} = Admin.delete_connection(conn.id)
          graph = Encyclopedia.build_graph()
          edit_mode = socket.assigns.edit_mode

          socket =
            socket
            |> assign_graph_data(graph, edit_mode)

          {:noreply,
           push_event(socket, "graph_updated", %{
             graph_json: socket.assigns.graph_json,
             edit_mode: edit_mode,
             orphans: if(edit_mode, do: GraphData.build_orphans_json(graph), else: "[]")
           })}
      end
    else
      {:noreply, socket}
    end
  end

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

  defp resolve_step_code(query, steps, fallback) do
    query = String.trim(to_string(query || ""))
    fallback = String.trim(to_string(fallback || ""))
    prefix = query |> String.split("·", parts: 2) |> List.first() |> String.trim()
    normalized_query = TextSearch.normalize(query)

    cond do
      query == "" ->
        fallback

      step_code?(steps, prefix) ->
        prefix

      match = Enum.find(steps, &(TextSearch.normalize(&1.code) == normalized_query)) ->
        match.code

      match = Enum.find(steps, &(TextSearch.normalize(&1.name) == normalized_query)) ->
        match.code

      true ->
        fallback
    end
  end

  defp step_code?(steps, code), do: Enum.any?(steps, &(&1.code == code))

  defp max_same_pair_loops("free"), do: 3
  defp max_same_pair_loops("light"), do: 2
  defp max_same_pair_loops(_mode), do: 1

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
