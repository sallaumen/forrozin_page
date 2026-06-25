defmodule OGrupoDeEstudosWeb.CollectionComponents do
  @moduledoc """
  Function components for the collection (acervo) view.

  Holds the expandable `step_item/1` row — with its inline like button, video
  links, embedded YouTube player and comment thread. Extracted from
  `CollectionLive` so the LiveView owns state and events while this module owns
  presentation.
  """

  use OGrupoDeEstudosWeb, :html

  import OGrupoDeEstudosWeb.UI.CommentThread

  attr :step, :map, required: true
  attr :current_user_id, :string, default: nil
  attr :steps_with_links, :any, default: %MapSet{}
  attr :step_likes, :map, default: %{liked_ids: %MapSet{}, counts: %{}}
  attr :expanded_step, :string, default: nil
  attr :expanded_comments, :list, default: []
  attr :expanded_links, :list, default: []
  attr :expanded_comment_likes, :map, default: %{liked_ids: %MapSet{}, counts: %{}}
  attr :expanded_replies_map, :map, default: %{}
  attr :expanded_replying_to, :string, default: nil
  attr :expanded_video, :string, default: nil
  attr :is_admin, :boolean, default: false
  attr :current_user, :map, default: nil

  @non_expandable_categories ~w(conceitos convencoes)

  def step_item(assigns) do
    has_links = MapSet.member?(assigns.steps_with_links, assigns.step.id)
    is_expanded = assigns.expanded_step == assigns.step.id

    cat_name =
      case assigns.step do
        %{category: %{name: name}} when is_binary(name) -> name
        _ -> nil
      end

    can_expand = cat_name not in @non_expandable_categories

    assigns =
      assign(assigns,
        has_links: has_links,
        is_expanded: is_expanded,
        can_expand: can_expand,
        is_deep_linked: assigns[:deep_linked_step_code] == assigns.step.code
      )

    ~H"""
    <% is_mine = @step.suggested_by_id != nil and @step.suggested_by_id == @current_user_id %>
    <div class={[
      "border-b border-ink-200/40 rounded-md mb-0.5",
      @is_deep_linked && "ring-2 ring-accent-orange/50 ring-offset-2 ring-offset-ink-50",
      is_mine && "bg-accent-pink-bg",
      !is_mine && "bg-transparent"
    ]}>
      <div
        id={"collection-step-list-#{@step.code}"}
        data-deep-linked={to_string(@is_deep_linked)}
        phx-click="open_step"
        phx-value-code={@step.code}
        class="flex gap-3.5 p-3 cursor-pointer"
      >
        <%= if @step.image_path do %>
          <img
            src={"/#{@step.image_path}"}
            alt={@step.code}
            loading="lazy"
            class="w-[72px] h-[72px] object-cover rounded flex-shrink-0 border border-ink-300/60"
            style="filter: sepia(20%);"
          />
        <% end %>
        <div class="flex-1 min-w-0">
          <div class="flex items-baseline gap-2.5 flex-wrap">
            <code class="font-mono text-xs font-bold text-ink-700 bg-gold-600/10 py-0.5 px-1.5 rounded-sm tracking-wide border border-gold-600/20">
              {@step.code}
            </code>
            <span class="text-sm text-ink-800 font-serif leading-normal">
              {@step.name}
            </span>
            <%= if @step.suggested_by_id do %>
              <.link
                navigate={
                  ~p"/users/#{if @step.suggested_by, do: @step.suggested_by.username, else: "#"}"
                }
                class="no-underline"
              >
                <span class={[
                  "text-[10px] py-px px-1.5 rounded-full italic border",
                  @step.approved && "border-accent-green/30 bg-accent-green/10 text-accent-green",
                  !@step.approved && "border-accent-purple/30 bg-accent-purple/10 text-accent-purple"
                ]}>
                  <%= if @step.approved do %>
                    ✓ @{if @step.suggested_by, do: @step.suggested_by.username, else: "?"}
                  <% else %>
                    Sugestão de @{if @step.suggested_by, do: @step.suggested_by.username, else: "?"}
                  <% end %>
                </span>
              </.link>
            <% end %>
          </div>
          <%= if @step.note do %>
            <p class="text-xs text-ink-600 mt-1 font-serif italic leading-relaxed">
              {String.slice(@step.note, 0, 120)}{if String.length(@step.note) > 120, do: "…"}
            </p>
          <% end %>
        </div>
        <div class="flex flex-col items-center gap-1 flex-shrink-0">
          <%= if @step.suggested_by_id do %>
            <span
              title="Contribuição da comunidade"
              class="flex items-center justify-center w-5 h-5 rounded-full bg-accent-purple/10 text-accent-purple"
            >
              <.icon name="hero-user" class="w-3 h-3" />
            </span>
          <% end %>
          <%= if @has_links do %>
            <span
              title="Tem vídeo/link"
              class="flex items-center justify-center w-5 h-5 rounded-full bg-accent-orange/10 text-accent-orange"
            >
              <.icon name="hero-play" class="w-3 h-3" />
            </span>
          <% end %>
          <button
            phx-click="toggle_step_like"
            phx-value-id={@step.id}
            class="flex items-center gap-0.5 p-0.5"
            title={
              if MapSet.member?(@step_likes.liked_ids, @step.id),
                do: "Remover curtida",
                else: "Curtir"
            }
          >
            <.icon
              name={
                if MapSet.member?(@step_likes.liked_ids, @step.id),
                  do: "hero-heart-solid",
                  else: "hero-heart"
              }
              class={[
                "w-4 h-4",
                MapSet.member?(@step_likes.liked_ids, @step.id) && "text-accent-red",
                !MapSet.member?(@step_likes.liked_ids, @step.id) &&
                  "text-ink-300 hover:text-accent-red/60"
              ]}
            />
            <span class="text-[10px] tabular-nums text-ink-400">
              {Map.get(@step_likes.counts, @step.id, 0)}
            </span>
          </button>
          <%!-- Expand/collapse — only for dance steps, not conventions/concepts --%>
          <%= if @can_expand do %>
            <button
              phx-click="toggle_step_expand"
              phx-value-step-id={@step.id}
              class={[
                "p-1 rounded-full transition-colors",
                @is_expanded && "text-accent-orange bg-accent-orange/10",
                !@is_expanded && "text-ink-400 hover:text-ink-600 hover:bg-ink-100"
              ]}
              title={if @is_expanded, do: "Fechar detalhes", else: "Ver detalhes"}
            >
              <.icon
                name={if @is_expanded, do: "hero-chevron-up-mini", else: "hero-chevron-down-mini"}
                class="w-4 h-4"
              />
            </button>
          <% end %>
        </div>
      </div>

      <%!-- Expanded content --%>
      <%= if @is_expanded && @can_expand do %>
        <div class="px-4 pb-4 space-y-4 border-t border-ink-100 pt-3">
          <%!-- Links / Videos --%>
          <%= if @expanded_links != [] do %>
            <div>
              <h4 class="text-xs font-bold text-ink-500 uppercase tracking-wider mb-2">Links</h4>
              <div class="space-y-2">
                <%= for link <- @expanded_links do %>
                  <div class="rounded-lg border border-ink-200 overflow-hidden">
                    <div class="flex items-center gap-2 px-3 py-2">
                      <a
                        href={link.url}
                        target="_blank"
                        rel="noopener"
                        class="flex-1 text-sm text-accent-orange hover:underline truncate no-underline"
                      >
                        {link.title || link.url}
                      </a>
                      <%= if youtube_id(link.url) do %>
                        <button
                          phx-click="toggle_expanded_video"
                          phx-value-link-id={link.id}
                          class={[
                            "text-xs py-1 px-2.5 rounded-full font-medium transition-colors",
                            @expanded_video == link.id && "bg-ink-200 text-ink-700",
                            @expanded_video != link.id && "bg-ink-100 text-ink-500 hover:bg-ink-200"
                          ]}
                        >
                          {if @expanded_video == link.id, do: "▲ Fechar", else: "▶ Assistir"}
                        </button>
                      <% end %>
                    </div>
                    <%= if @expanded_video == link.id && youtube_id(link.url) do %>
                      <div class="relative pb-[56.25%] h-0 overflow-hidden bg-ink-900">
                        <iframe
                          src={"https://www.youtube.com/embed/#{youtube_id(link.url)}"}
                          class="absolute top-0 left-0 w-full h-full"
                          frameborder="0"
                          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                          allowfullscreen
                        />
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <%!-- Comments --%>
          <div>
            <h4 class="text-xs font-bold text-ink-500 uppercase tracking-wider mb-2">Comentários</h4>
            <.comment_thread
              comments={@expanded_comments}
              current_user={@current_user}
              likes_map={@expanded_comment_likes}
              comment_type="step_comment"
              parent_id={@step.id}
              replying_to={@expanded_replying_to}
              replies_map={@expanded_replies_map}
              is_admin={@is_admin}
            />
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp youtube_id(url) when is_binary(url) do
    cond do
      String.contains?(url, "youtube.com/watch") ->
        URI.parse(url) |> Map.get(:query, "") |> URI.decode_query() |> Map.get("v")

      String.contains?(url, "youtu.be/") ->
        URI.parse(url) |> Map.get(:path, "") |> String.trim_leading("/")

      true ->
        nil
    end
  end

  defp youtube_id(_), do: nil
end
