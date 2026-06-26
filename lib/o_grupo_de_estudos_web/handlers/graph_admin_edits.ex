defmodule OGrupoDeEstudosWeb.Handlers.GraphAdminEdits do
  @moduledoc """
  Macro com os handlers de edição do grafo da GraphVisualLive: alternar modo de
  edição, criar/deletar conexões (admin) e a UI de aresta faltante (admin cria,
  qualquer usuário sugere).

  Uso: `use OGrupoDeEstudosWeb.Handlers.GraphAdminEdits`

  As cláusulas admin preservam o gate `if socket.assigns.is_admin`. Requer o
  assign `:edit_mode`, `:seq_suggested_edges` e os helpers privados do host
  `assign_graph_data/3` e `do_create_missing_connection/3`. Empurra
  "graph_updated" / "graph_error" para o hook Cytoscape.
  """

  defmacro __using__(_opts) do
    quote do
      alias OGrupoDeEstudos.{Admin, Encyclopedia}
      alias OGrupoDeEstudos.Encyclopedia.{ConnectionQuery, StepQuery}
      alias OGrupoDeEstudosWeb.GraphVisual.GraphData

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
                 new_value: "#{src_code}→#{tgt_code}"
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
    end
  end
end
