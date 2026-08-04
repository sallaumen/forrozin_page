defmodule OGrupoDeEstudosWeb.Handlers.GraphAdminEdits do
  @moduledoc """
  Macro with the graph editing handlers of GraphVisualLive: toggling edit mode,
  creating and deleting connections (admin) and the missing-edge UI.
  """

  defmacro __using__(_opts) do
    quote do
      alias OGrupoDeEstudos.{Admin, Encyclopedia}
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
        source = Encyclopedia.get_step_by(code: src_code)

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
          with source when not is_nil(source) <- Encyclopedia.get_step_by(code: source_code),
               target when not is_nil(target) <- Encyclopedia.get_step_by(code: target_code),
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
          connection =
            Encyclopedia.get_connection_by(source_code: source_code, target_code: target_code)

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
