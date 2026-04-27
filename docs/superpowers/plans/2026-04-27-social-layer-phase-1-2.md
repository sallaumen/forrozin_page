# Social Layer (Phases 1-2): Follow Inline + Floating Bubble — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Spread follow buttons across every page of the app and add a persistent floating bubble with people suggestions, so social features are impossible to miss.

**Architecture:** Create a reusable `InlineFollowButton` component and a `FollowHandlers` macro to DRY up the toggle_follow event across LiveViews. Add the button to CollectionLive, StepLive, and GraphVisualLive. Then create a `SocialBubble` component with popover that renders on all authenticated pages (mobile only).

**Tech Stack:** Phoenix LiveView, Elixir macros, Tailwind CSS, ExMachina (tests)

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/o_grupo_de_estudos_web/components/ui/inline_follow_button.ex` | Create | Reusable follow/following button component |
| `lib/o_grupo_de_estudos_web/handlers/follow_handlers.ex` | Create | Macro providing `toggle_follow` event handler |
| `lib/o_grupo_de_estudos_web/live/collection_live.ex` | Modify | Add follow handlers + following_user_ids assign |
| `lib/o_grupo_de_estudos_web/live/collection_live.html.heex` | Modify | Add inline follow button in drawer |
| `lib/o_grupo_de_estudos_web/live/step_live.ex` | Modify | Add follow handlers + following_user_ids assign |
| `lib/o_grupo_de_estudos_web/live/step_live.html.heex` | Modify | Add inline follow button next to "Sugerido por" and "Editado por" |
| `lib/o_grupo_de_estudos_web/live/graph_visual_live.ex` | Modify | Add follow handlers + following_user_ids assign |
| `lib/o_grupo_de_estudos_web/live/graph_visual_live.html.heex` | Modify | Add inline follow button next to sequence author |
| `lib/o_grupo_de_estudos_web/live/community_live.ex` | Modify | Refactor to use FollowHandlers macro |
| `lib/o_grupo_de_estudos_web/components/ui/social_bubble.ex` | Create | Floating bubble + popover component (mobile) |
| `lib/o_grupo_de_estudos_web/handlers/social_bubble_handlers.ex` | Create | Macro providing bubble toggle/follow events |
| `test/o_grupo_de_estudos_web/components/inline_follow_button_test.exs` | Create | Component tests |
| `test/o_grupo_de_estudos_web/live/collection_live_test.exs` | Modify | Follow button tests |
| `test/o_grupo_de_estudos_web/live/step_live_test.exs` | Modify | Follow button tests |

---

### Task 1: Create InlineFollowButton component

**Files:**
- Create: `lib/o_grupo_de_estudos_web/components/ui/inline_follow_button.ex`
- Create: `test/o_grupo_de_estudos_web/components/inline_follow_button_test.exs`

- [ ] **Step 1: Write component test**

```elixir
# test/o_grupo_de_estudos_web/components/inline_follow_button_test.exs
defmodule OGrupoDeEstudosWeb.UI.InlineFollowButtonTest do
  use OGrupoDeEstudosWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias OGrupoDeEstudosWeb.UI.InlineFollowButton

  describe "inline_follow_button/1" do
    test "renders nothing when target is current user" do
      assigns = %{
        target_user_id: "user-1",
        current_user_id: "user-1",
        following_user_ids: MapSet.new()
      }

      html = rendered_to_string(~H"""
      <InlineFollowButton.inline_follow_button
        target_user_id={@target_user_id}
        current_user_id={@current_user_id}
        following_user_ids={@following_user_ids}
      />
      """)

      refute html =~ "Seguir"
      refute html =~ "Seguindo"
    end

    test "renders Seguir when not following" do
      assigns = %{
        target_user_id: "user-2",
        current_user_id: "user-1",
        following_user_ids: MapSet.new()
      }

      html = rendered_to_string(~H"""
      <InlineFollowButton.inline_follow_button
        target_user_id={@target_user_id}
        current_user_id={@current_user_id}
        following_user_ids={@following_user_ids}
      />
      """)

      assert html =~ "Seguir"
      refute html =~ "Seguindo"
    end

    test "renders Seguindo when already following" do
      assigns = %{
        target_user_id: "user-2",
        current_user_id: "user-1",
        following_user_ids: MapSet.new(["user-2"])
      }

      html = rendered_to_string(~H"""
      <InlineFollowButton.inline_follow_button
        target_user_id={@target_user_id}
        current_user_id={@current_user_id}
        following_user_ids={@following_user_ids}
      />
      """)

      assert html =~ "Seguindo"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/o_grupo_de_estudos_web/components/inline_follow_button_test.exs --seed 0`
Expected: FAIL — module not found

- [ ] **Step 3: Implement the component**

```elixir
# lib/o_grupo_de_estudos_web/components/ui/inline_follow_button.ex
defmodule OGrupoDeEstudosWeb.UI.InlineFollowButton do
  @moduledoc """
  Inline follow/following button. Renders next to usernames across the app.

  Renders nothing if target_user_id == current_user_id.
  Emits `phx-click="toggle_follow"` with `phx-value-user-id`.
  """

  use Phoenix.Component

  attr :target_user_id, :string, required: true
  attr :current_user_id, :string, required: true
  attr :following_user_ids, :any, required: true

  def inline_follow_button(assigns) do
    ~H"""
    <%= if @target_user_id && @target_user_id != @current_user_id do %>
      <% is_following = MapSet.member?(@following_user_ids, @target_user_id) %>
      <button
        phx-click="toggle_follow"
        phx-value-user-id={@target_user_id}
        class={[
          "text-xs py-1 px-3 rounded-full border font-medium transition-colors cursor-pointer flex-shrink-0",
          is_following && "border-accent-orange bg-accent-orange/10 text-accent-orange",
          !is_following && "border-accent-orange bg-accent-orange text-white hover:bg-accent-orange/90"
        ]}
      >
        {if is_following, do: "Seguindo ✓", else: "Seguir"}
      </button>
    <% end %>
    """
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/o_grupo_de_estudos_web/components/inline_follow_button_test.exs --seed 0`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/o_grupo_de_estudos_web/components/ui/inline_follow_button.ex test/o_grupo_de_estudos_web/components/inline_follow_button_test.exs
git commit -m "feat: create InlineFollowButton component"
```

---

### Task 2: Create FollowHandlers macro

**Files:**
- Create: `lib/o_grupo_de_estudos_web/handlers/follow_handlers.ex`

- [ ] **Step 1: Create the handlers directory if needed and implement the macro**

```elixir
# lib/o_grupo_de_estudos_web/handlers/follow_handlers.ex
defmodule OGrupoDeEstudosWeb.Handlers.FollowHandlers do
  @moduledoc """
  Macro providing a generic `toggle_follow` event handler.

  Usage: `use OGrupoDeEstudosWeb.Handlers.FollowHandlers`

  Requires the LiveView to have `following_user_ids` in its assigns (a MapSet).
  On toggle, refreshes `following_user_ids` from the database.
  """

  defmacro __using__(_opts) do
    quote do
      def handle_event("toggle_follow", %{"user-id" => target_id}, socket) do
        user = socket.assigns.current_user
        result = OGrupoDeEstudos.Engagement.toggle_follow(user.id, target_id)
        socket = OGrupoDeEstudosWeb.Helpers.RateLimit.maybe_flash_rate_limit(socket, result)
        following = OGrupoDeEstudos.Engagement.following_ids(user.id)
        {:noreply, assign(socket, following_user_ids: following)}
      end
    end
  end
end
```

- [ ] **Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors 2>&1 | tail -5`
Expected: compiles successfully

- [ ] **Step 3: Commit**

```bash
git add lib/o_grupo_de_estudos_web/handlers/follow_handlers.ex
git commit -m "feat: create FollowHandlers macro for toggle_follow"
```

---

### Task 3: Add follow inline to CollectionLive (Acervo)

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/live/collection_live.ex`
- Modify: `lib/o_grupo_de_estudos_web/live/collection_live.html.heex`
- Modify: `test/o_grupo_de_estudos_web/live/collection_live_test.exs`

- [ ] **Step 1: Write failing LiveView test**

In `test/o_grupo_de_estudos_web/live/collection_live_test.exs`, add:

```elixir
describe "inline follow button" do
  test "shows follow button for step author in drawer", %{conn: conn} do
    user = insert(:user)
    conn = log_in_user(conn, user)
    author = insert(:user, username: "forro_author")
    section = insert(:section)
    step = insert(:step, section: section, code: "FLW-T", suggested_by: author, approved: true)

    {:ok, lv, _html} = live(conn, ~p"/collection")
    html = render_click(lv, "open_step_drawer", %{"code" => step.code})

    assert html =~ "Seguir"
    assert html =~ "forro_author"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/o_grupo_de_estudos_web/live/collection_live_test.exs --seed 0 -t "inline follow"`
Expected: FAIL — "Seguir" not found in drawer HTML

- [ ] **Step 3: Add follow support to CollectionLive backend**

In `lib/o_grupo_de_estudos_web/live/collection_live.ex`:

1. Add import after existing imports:
```elixir
import OGrupoDeEstudosWeb.UI.InlineFollowButton
```

2. Add `use` after existing `use` statements:
```elixir
use OGrupoDeEstudosWeb.Handlers.FollowHandlers
```

3. In mount assigns (around line 47), add:
```elixir
following_user_ids: Engagement.following_ids(socket.assigns.current_user.id),
```

Note: `Engagement` is already aliased in this module.

- [ ] **Step 4: Add follow button to drawer in HEEX template**

In `lib/o_grupo_de_estudos_web/live/collection_live.html.heex`, find the author section in the drawer (around line 553-598). After the `</.link>` that wraps the author badge (around line 597), add:

```heex
<.inline_follow_button
  target_user_id={@drawer_item.suggested_by_id}
  current_user_id={@current_user.id}
  following_user_ids={@following_user_ids}
/>
```

Place it inside the `<div class="mt-2.5 flex items-center gap-2">` that wraps the author info, so it appears inline with the username.

- [ ] **Step 5: Run test to verify it passes**

Run: `mix test test/o_grupo_de_estudos_web/live/collection_live_test.exs --seed 0 -t "inline follow"`
Expected: PASS

- [ ] **Step 6: Run full collection test suite**

Run: `mix test test/o_grupo_de_estudos_web/live/collection_live_test.exs --seed 0`
Expected: all pass

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: add inline follow button to CollectionLive drawer"
```

---

### Task 4: Add follow inline to StepLive (Detalhe do Passo)

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/live/step_live.ex`
- Modify: `lib/o_grupo_de_estudos_web/live/step_live.html.heex`
- Modify: `test/o_grupo_de_estudos_web/live/step_live_test.exs`

- [ ] **Step 1: Write failing test**

In `test/o_grupo_de_estudos_web/live/step_live_test.exs`, add:

```elixir
describe "inline follow button" do
  test "shows follow button next to suggested by", %{conn: conn} do
    user = insert(:user)
    conn = log_in_user(conn, user)
    author = insert(:user, username: "step_author")
    section = insert(:section)
    step = insert(:step, section: section, code: "FLW-S", suggested_by: author, approved: true)

    {:ok, _lv, html} = live(conn, ~p"/steps/#{step.code}")

    assert html =~ "Seguir"
    assert html =~ "step_author"
  end

  test "does not show follow button for own step", %{conn: conn} do
    user = insert(:user)
    conn = log_in_user(conn, user)
    section = insert(:section)
    step = insert(:step, section: section, code: "FLW-O", suggested_by: user, approved: true)

    {:ok, _lv, html} = live(conn, ~p"/steps/#{step.code}")

    refute html =~ ">Seguir<"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/o_grupo_de_estudos_web/live/step_live_test.exs --seed 0 -t "inline follow"`
Expected: FAIL

- [ ] **Step 3: Add follow support to StepLive backend**

In `lib/o_grupo_de_estudos_web/live/step_live.ex`:

1. Add import:
```elixir
import OGrupoDeEstudosWeb.UI.InlineFollowButton
```

2. Add `use`:
```elixir
use OGrupoDeEstudosWeb.Handlers.FollowHandlers
```

3. In the mount assigns (around line 65), add:
```elixir
following_user_ids: Engagement.following_ids(user_id),
```

Note: `Engagement` is already aliased and `user_id` is already defined at line 21.

- [ ] **Step 4: Add follow button next to "Sugerido por" badge in HEEX**

In `lib/o_grupo_de_estudos_web/live/step_live.html.heex`, find the "Sugerido por" badge (lines 140-159). The badge is inside a `<div class="mb-2 flex items-center gap-2">`. After the `</.link>` that closes the badge (line 157), add:

```heex
<.inline_follow_button
  target_user_id={@step.suggested_by_id}
  current_user_id={@current_user.id}
  following_user_ids={@following_user_ids}
/>
```

- [ ] **Step 5: Add follow button next to "Editado por" badge**

Find the "Editado por" section (lines 381-392). After the `</.link>` (line 390), add:

```heex
<.inline_follow_button
  target_user_id={@step.last_edited_by_id}
  current_user_id={@current_user.id}
  following_user_ids={@following_user_ids}
/>
```

- [ ] **Step 6: Run tests**

Run: `mix test test/o_grupo_de_estudos_web/live/step_live_test.exs --seed 0`
Expected: all pass

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: add inline follow button to StepLive"
```

---

### Task 5: Add follow inline to GraphVisualLive (Mapa)

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/live/graph_visual_live.ex`
- Modify: `lib/o_grupo_de_estudos_web/live/graph_visual_live.html.heex`

- [ ] **Step 1: Add follow support to GraphVisualLive backend**

In `lib/o_grupo_de_estudos_web/live/graph_visual_live.ex`:

1. Add import:
```elixir
import OGrupoDeEstudosWeb.UI.InlineFollowButton
```

2. Add `use`:
```elixir
use OGrupoDeEstudosWeb.Handlers.FollowHandlers
```

3. In mount assigns, add:
```elixir
following_user_ids: Engagement.following_ids(socket.assigns.current_user.id),
```

Check if `Engagement` is already aliased. If not, add: `alias OGrupoDeEstudos.Engagement`

- [ ] **Step 2: Add follow button next to sequence author in HEEX**

In `lib/o_grupo_de_estudos_web/live/graph_visual_live.html.heex`, find where the sequence author is displayed (around line 903-905, showing `· @{seq.user.username}`). After the username text, add:

```heex
<.inline_follow_button
  :if={seq.user}
  target_user_id={seq.user_id}
  current_user_id={@current_user.id}
  following_user_ids={@following_user_ids}
/>
```

- [ ] **Step 3: Run compilation and existing tests**

Run: `mix compile --warnings-as-errors && mix test test/o_grupo_de_estudos_web/live/graph_visual_live_test.exs --seed 0 2>&1 | tail -5`
Expected: compiles, tests pass

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: add inline follow button to GraphVisualLive"
```

---

### Task 6: Refactor CommunityLive to use FollowHandlers macro

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/live/community_live.ex`

- [ ] **Step 1: Read current CommunityLive toggle_follow handler**

The current `toggle_follow` handler in CommunityLive (around line 181) does extra work beyond the basic follow toggle — it refreshes followers_list, followers_stats, suggested_users, etc. The macro provides only the basic handler. Since CommunityLive needs the extended version, we need to keep the custom handler but NOT use the macro (the macro's `def handle_event("toggle_follow", ...)` would conflict).

**Decision:** Do NOT add the macro to CommunityLive. It already has its own, more specialized `toggle_follow` handler. The macro is for pages that didn't have follow support before.

Instead, just add the `import OGrupoDeEstudosWeb.UI.InlineFollowButton` if not already imported (it may not be needed if community_live already has its own follow buttons inline).

- [ ] **Step 2: Verify no changes needed**

Run: `mix test test/o_grupo_de_estudos_web/live/community_live_test.exs --seed 0`
Expected: all pass (no changes)

- [ ] **Step 3: Commit (skip if no changes)**

No commit needed if no changes were made.

---

### Task 7: Create SocialBubble component

**Files:**
- Create: `lib/o_grupo_de_estudos_web/components/ui/social_bubble.ex`

- [ ] **Step 1: Implement the SocialBubble component**

```elixir
# lib/o_grupo_de_estudos_web/components/ui/social_bubble.ex
defmodule OGrupoDeEstudosWeb.UI.SocialBubble do
  @moduledoc """
  Floating social bubble (mobile only).

  Shows a persistent FAB in the bottom-right corner. When tapped, opens a
  popover with people suggestions and a search link. Closes on outside tap.

  Rendered on all authenticated pages via each LiveView template,
  positioned above the bottom nav.
  """

  use Phoenix.Component
  use OGrupoDeEstudosWeb, :verified_routes

  import OGrupoDeEstudosWeb.UI.InlineFollowButton

  attr :current_user, :map, required: true
  attr :suggested_users, :list, default: []
  attr :following_user_ids, :any, default: MapSet.new()
  attr :bubble_open, :boolean, default: false

  def social_bubble(assigns) do
    ~H"""
    <div data-ui="social-bubble" class="md:hidden" phx-click-away="close_bubble">
      <%!-- Popover --%>
      <div
        :if={@bubble_open}
        class="fixed bottom-[88px] right-4 z-50 bg-ink-50 rounded-xl shadow-xl border border-ink-200 w-56 overflow-hidden animate-fade-in"
        style="animation: fadeSlideUp 0.15s ease-out;"
      >
        <%!-- Arrow --%>
        <div class="absolute -bottom-1.5 right-5 w-3 h-3 bg-ink-50 border-r border-b border-ink-200 rotate-45" />

        <div class="p-3">
          <p class="text-xs font-bold text-ink-700 mb-2.5">Seguir alguem?</p>

          <%= if @suggested_users == [] do %>
            <p class="text-xs text-ink-400 italic py-3 text-center">
              Voce ja segue todo mundo!
            </p>
          <% else %>
            <div class="space-y-2">
              <%= for person <- Enum.take(@suggested_users, 3) do %>
                <div class="flex items-center gap-2">
                  <.link
                    navigate={~p"/users/#{person.username}"}
                    class="no-underline flex items-center gap-2 flex-1 min-w-0"
                  >
                    <span class="inline-flex items-center justify-center w-7 h-7 rounded-full bg-ink-800 text-ink-200 text-[10px] font-bold flex-shrink-0">
                      {person.username |> String.upcase() |> String.first()}
                    </span>
                    <div class="flex-1 min-w-0">
                      <p class="text-xs font-semibold text-ink-800 truncate">
                        @{person.username}
                      </p>
                      <p :if={person.city} class="text-[10px] text-ink-400 truncate">
                        {person.city}
                      </p>
                    </div>
                  </.link>
                  <.inline_follow_button
                    target_user_id={person.id}
                    current_user_id={@current_user.id}
                    following_user_ids={@following_user_ids}
                  />
                </div>
              <% end %>
            </div>
          <% end %>

          <div class="border-t border-ink-200 mt-2.5 pt-2 text-center">
            <.link
              navigate={~p"/users/#{@current_user.username}"}
              class="text-xs text-accent-orange font-semibold no-underline"
            >
              Ver meu perfil
            </.link>
          </div>
        </div>
      </div>

      <%!-- Bubble FAB --%>
      <button
        phx-click="toggle_bubble"
        class={[
          "fixed bottom-20 right-4 z-40 w-12 h-12 rounded-full flex items-center justify-center cursor-pointer border-0 shadow-lg transition-all",
          @bubble_open && "bg-ink-700 shadow-xl scale-95",
          !@bubble_open && "bg-gradient-to-br from-accent-orange to-[#d35400] shadow-accent-orange/30"
        ]}
        style={if !@bubble_open, do: "animation: bubble-pulse 3s ease-in-out infinite;", else: ""}
      >
        <span class="text-lg">
          {if @bubble_open, do: "✕", else: "👥"}
        </span>
        <%= if !@bubble_open && length(@suggested_users) > 0 do %>
          <span class="absolute -top-0.5 -right-0.5 min-w-[16px] h-4 px-0.5 flex items-center justify-center bg-accent-red text-white text-[9px] font-bold rounded-full">
            {length(@suggested_users)}
          </span>
        <% end %>
      </button>

      <style>
        @keyframes bubble-pulse {
          0%, 100% { transform: scale(1); }
          50% { transform: scale(1.06); }
        }
        @keyframes fadeSlideUp {
          from { opacity: 0; transform: translateY(8px); }
          to { opacity: 1; transform: translateY(0); }
        }
      </style>
    </div>
    """
  end
end
```

- [ ] **Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors 2>&1 | tail -5`
Expected: compiles

- [ ] **Step 3: Commit**

```bash
git add lib/o_grupo_de_estudos_web/components/ui/social_bubble.ex
git commit -m "feat: create SocialBubble component with popover"
```

---

### Task 8: Create SocialBubbleHandlers macro

**Files:**
- Create: `lib/o_grupo_de_estudos_web/handlers/social_bubble_handlers.ex`

- [ ] **Step 1: Implement the macro**

```elixir
# lib/o_grupo_de_estudos_web/handlers/social_bubble_handlers.ex
defmodule OGrupoDeEstudosWeb.Handlers.SocialBubbleHandlers do
  @moduledoc """
  Macro providing event handlers for the SocialBubble component.

  Usage: `use OGrupoDeEstudosWeb.Handlers.SocialBubbleHandlers`

  Provides:
  - `toggle_bubble` — opens/closes the popover
  - `close_bubble` — closes the popover (used by phx-click-away)

  Requires `bubble_open`, `suggested_users`, and `following_user_ids` assigns.
  """

  defmacro __using__(_opts) do
    quote do
      def handle_event("toggle_bubble", _params, socket) do
        is_open = !socket.assigns[:bubble_open]

        socket =
          if is_open and socket.assigns[:suggested_users] in [nil, []] do
            users =
              OGrupoDeEstudos.Engagement.suggest_users(
                socket.assigns.current_user,
                limit: 3
              )

            assign(socket, suggested_users: users, bubble_open: true)
          else
            assign(socket, bubble_open: is_open)
          end

        {:noreply, socket}
      end

      def handle_event("close_bubble", _params, socket) do
        {:noreply, assign(socket, bubble_open: false)}
      end
    end
  end
end
```

- [ ] **Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors 2>&1 | tail -5`
Expected: compiles

- [ ] **Step 3: Commit**

```bash
git add lib/o_grupo_de_estudos_web/handlers/social_bubble_handlers.ex
git commit -m "feat: create SocialBubbleHandlers macro"
```

---

### Task 9: Wire SocialBubble into CollectionLive

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/live/collection_live.ex`
- Modify: `lib/o_grupo_de_estudos_web/live/collection_live.html.heex`
- Modify: `test/o_grupo_de_estudos_web/live/collection_live_test.exs`

- [ ] **Step 1: Write failing test**

In `test/o_grupo_de_estudos_web/live/collection_live_test.exs`, add:

```elixir
describe "social bubble" do
  test "shows floating bubble on page load", %{conn: conn} do
    user = insert(:user)
    conn = log_in_user(conn, user)
    _suggestion = insert(:user, city: user.city || "Curitiba", state: user.state || "PR")

    {:ok, _lv, html} = live(conn, ~p"/collection")

    assert html =~ "social-bubble"
  end

  test "opens popover with suggestions on toggle", %{conn: conn} do
    user = insert(:user)
    conn = log_in_user(conn, user)
    suggestion = insert(:user, city: user.city || "Curitiba", state: user.state || "PR")

    {:ok, lv, _html} = live(conn, ~p"/collection")
    html = render_click(lv, "toggle_bubble")

    assert html =~ "Seguir alguem?"
    assert html =~ suggestion.username
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/o_grupo_de_estudos_web/live/collection_live_test.exs --seed 0 -t "social bubble"`
Expected: FAIL

- [ ] **Step 3: Add bubble support to CollectionLive backend**

In `lib/o_grupo_de_estudos_web/live/collection_live.ex`:

1. Add import:
```elixir
import OGrupoDeEstudosWeb.UI.SocialBubble
```

2. Add `use`:
```elixir
use OGrupoDeEstudosWeb.Handlers.SocialBubbleHandlers
```

3. In mount assigns, add:
```elixir
bubble_open: false,
suggested_users: [],
```

- [ ] **Step 4: Add bubble to HEEX template**

In `lib/o_grupo_de_estudos_web/live/collection_live.html.heex`, just before `<.bottom_nav` (around line 908), add:

```heex
<.social_bubble
  current_user={@current_user}
  suggested_users={@suggested_users}
  following_user_ids={@following_user_ids}
  bubble_open={@bubble_open}
/>
```

- [ ] **Step 5: Run tests**

Run: `mix test test/o_grupo_de_estudos_web/live/collection_live_test.exs --seed 0`
Expected: all pass

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: add SocialBubble to CollectionLive"
```

---

### Task 10: Wire SocialBubble into StepLive

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/live/step_live.ex`
- Modify: `lib/o_grupo_de_estudos_web/live/step_live.html.heex`

- [ ] **Step 1: Add bubble support to StepLive backend**

In `lib/o_grupo_de_estudos_web/live/step_live.ex`:

1. Add import:
```elixir
import OGrupoDeEstudosWeb.UI.SocialBubble
```

2. Add `use`:
```elixir
use OGrupoDeEstudosWeb.Handlers.SocialBubbleHandlers
```

3. In mount assigns, add:
```elixir
bubble_open: false,
suggested_users: [],
```

- [ ] **Step 2: Add bubble to HEEX template**

In `lib/o_grupo_de_estudos_web/live/step_live.html.heex`, find `<.bottom_nav` and add just before it:

```heex
<.social_bubble
  current_user={@current_user}
  suggested_users={@suggested_users}
  following_user_ids={@following_user_ids}
  bubble_open={@bubble_open}
/>
```

- [ ] **Step 3: Run tests**

Run: `mix test test/o_grupo_de_estudos_web/live/step_live_test.exs --seed 0`
Expected: all pass

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: add SocialBubble to StepLive"
```

---

### Task 11: Wire SocialBubble into GraphVisualLive

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/live/graph_visual_live.ex`
- Modify: `lib/o_grupo_de_estudos_web/live/graph_visual_live.html.heex`

- [ ] **Step 1: Add bubble support to GraphVisualLive backend**

In `lib/o_grupo_de_estudos_web/live/graph_visual_live.ex`:

1. Add import:
```elixir
import OGrupoDeEstudosWeb.UI.SocialBubble
```

2. Add `use`:
```elixir
use OGrupoDeEstudosWeb.Handlers.SocialBubbleHandlers
```

3. In mount assigns, add:
```elixir
bubble_open: false,
suggested_users: [],
```

Check if `following_user_ids` was already added in Task 5. If so, no need to add again.

- [ ] **Step 2: Add bubble to HEEX template**

In `lib/o_grupo_de_estudos_web/live/graph_visual_live.html.heex`, find `<.bottom_nav` and add just before it:

```heex
<.social_bubble
  current_user={@current_user}
  suggested_users={@suggested_users}
  following_user_ids={@following_user_ids}
  bubble_open={@bubble_open}
/>
```

- [ ] **Step 3: Run tests**

Run: `mix test test/o_grupo_de_estudos_web/live/graph_visual_live_test.exs --seed 0 2>&1 | tail -5`
Expected: all pass

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: add SocialBubble to GraphVisualLive"
```

---

### Task 12: Wire SocialBubble into remaining authenticated pages

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/live/study_live.ex`
- Modify: `lib/o_grupo_de_estudos_web/live/study_live.html.heex`
- Modify: `lib/o_grupo_de_estudos_web/live/notifications_live.ex`
- Modify: `lib/o_grupo_de_estudos_web/live/notifications_live.html.heex`
- Modify: `lib/o_grupo_de_estudos_web/live/user_profile_live.ex`
- Modify: `lib/o_grupo_de_estudos_web/live/user_profile_live.html.heex`
- Modify: `lib/o_grupo_de_estudos_web/live/community_live.ex`
- Modify: `lib/o_grupo_de_estudos_web/live/community_live.html.heex`
- Modify: `lib/o_grupo_de_estudos_web/live/settings_live.ex` (if it has bottom_nav)
- Modify: `lib/o_grupo_de_estudos_web/live/settings_live.html.heex` (if it has bottom_nav)

- [ ] **Step 1: For EACH LiveView that has `<.bottom_nav`**

Apply the same pattern as Tasks 9-11:

1. Add `import OGrupoDeEstudosWeb.UI.SocialBubble`
2. Add `use OGrupoDeEstudosWeb.Handlers.SocialBubbleHandlers`
3. Add `bubble_open: false, suggested_users: []` to mount assigns
4. Add `following_user_ids: Engagement.following_ids(...)` to mount assigns IF not already present
5. Add `<.social_bubble .../>` just before `<.bottom_nav` in the HEEX template

First, find all pages with `<.bottom_nav`:
```bash
grep -rn "bottom_nav" lib/o_grupo_de_estudos_web/live/ --include="*.heex" -l
```

Apply to each one. For CommunityLive, it already has `following_user_ids` and `suggested_users` — just add the bubble import, handlers, and template element.

For pages that don't have `Engagement` aliased, add the alias.

- [ ] **Step 2: Run full test suite**

Run: `mix test --seed 0 2>&1 | tail -10`
Expected: all pass (except pre-existing dispatcher failures)

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add SocialBubble to all authenticated pages"
```

---

### Task 13: FollowHandlers integration — refresh bubble after follow

**Files:**
- Modify: `lib/o_grupo_de_estudos_web/handlers/follow_handlers.ex`

- [ ] **Step 1: Update FollowHandlers to also refresh suggested_users**

When a user follows someone via the inline button OR via the bubble popover, the suggestions should update. Modify the macro:

```elixir
defmacro __using__(_opts) do
  quote do
    def handle_event("toggle_follow", %{"user-id" => target_id}, socket) do
      user = socket.assigns.current_user
      result = OGrupoDeEstudos.Engagement.toggle_follow(user.id, target_id)
      socket = OGrupoDeEstudosWeb.Helpers.RateLimit.maybe_flash_rate_limit(socket, result)
      following = OGrupoDeEstudos.Engagement.following_ids(user.id)

      socket = assign(socket, following_user_ids: following)

      # Refresh bubble suggestions if bubble is present
      socket =
        if Map.has_key?(socket.assigns, :suggested_users) do
          users = OGrupoDeEstudos.Engagement.suggest_users(user, limit: 3)
          assign(socket, suggested_users: users)
        else
          socket
        end

      {:noreply, socket}
    end
  end
end
```

- [ ] **Step 2: Verify tests pass**

Run: `mix test test/o_grupo_de_estudos_web/live/collection_live_test.exs test/o_grupo_de_estudos_web/live/step_live_test.exs --seed 0`
Expected: all pass

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: refresh bubble suggestions after follow toggle"
```
