defmodule OGrupoDeEstudosWeb.CollectionComponents do
  @moduledoc """
  Function components for the collection (acervo) view.

  Holds the `step_item/1` row used in search and "Meus passos" listings. Clicking
  a row opens the shared step drawer (`open_step`), where the full
  `OGrupoDeEstudosWeb.StepDetail` experience is rendered.
  """

  use OGrupoDeEstudosWeb, :html

  attr :step, :map, required: true
  attr :current_user_id, :string, default: nil
  attr :steps_with_links, :any, default: %MapSet{}
  attr :step_likes, :map, default: %{liked_ids: %MapSet{}, counts: %{}}

  def step_item(assigns) do
    assigns =
      assign(assigns,
        has_links: MapSet.member?(assigns.steps_with_links, assigns.step.id),
        is_mine:
          assigns.step.suggested_by_id != nil and
            assigns.step.suggested_by_id == assigns.current_user_id
      )

    ~H"""
    <div class={[
      "border-b border-ink-200/40 rounded-md mb-0.5",
      @is_mine && "bg-accent-pink-bg",
      !@is_mine && "bg-transparent"
    ]}>
      <div
        id={"collection-step-list-#{@step.code}"}
        phx-click="open_step"
        phx-value-code={@step.code}
        class="flex gap-3.5 p-3 cursor-pointer"
      >
        <img
          :if={@step.image_path}
          src={"/#{@step.image_path}"}
          alt={@step.code}
          loading="lazy"
          class="w-[72px] h-[72px] object-cover rounded flex-shrink-0 border border-ink-300/60"
          style="filter: sepia(20%);"
        />
        <div class="flex-1 min-w-0">
          <div class="flex items-baseline gap-2.5 flex-wrap">
            <code class="font-mono text-xs font-bold text-ink-700 bg-gold-600/10 py-0.5 px-1.5 rounded-sm tracking-wide border border-gold-600/20">
              {@step.code}
            </code>
            <span class="text-sm text-ink-800 font-serif leading-normal">
              {@step.name}
            </span>
            <.link
              :if={@step.suggested_by_id}
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
          </div>
          <p :if={@step.note} class="text-xs text-ink-600 mt-1 font-serif italic leading-relaxed">
            {String.slice(@step.note, 0, 120)}{if String.length(@step.note) > 120, do: "…"}
          </p>
        </div>
        <div class="flex flex-col items-center gap-1 flex-shrink-0">
          <span
            :if={@step.suggested_by_id}
            title="Contribuição da comunidade"
            class="flex items-center justify-center w-5 h-5 rounded-full bg-accent-purple/10 text-accent-purple"
          >
            <.icon name="hero-user" class="w-3 h-3" />
          </span>
          <span
            :if={@has_links}
            title="Tem vídeo/link"
            class="flex items-center justify-center w-5 h-5 rounded-full bg-accent-orange/10 text-accent-orange"
          >
            <.icon name="hero-play" class="w-3 h-3" />
          </span>
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
        </div>
      </div>
    </div>
    """
  end
end
