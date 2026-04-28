defmodule OGrupoDeEstudosWeb.UI.ActivityToast do
  @moduledoc """
  Ephemeral activity toast component.

  Shows a slim bar at the top of the screen when someone the user
  follows does something (like a step, create a sequence, etc.).

  Slides down, auto-dismisses after 4 seconds.

  ## Disabling

  Remove `<.activity_toast>` calls from templates. The handler
  will still receive messages but won't render anything.
  """

  use Phoenix.Component

  def activity_toast(assigns) do
    ~H"""
    <div
      :if={@toast}
      class="fixed top-14 left-1/2 -translate-x-1/2 z-50 max-w-sm w-[calc(100%-2rem)] pointer-events-auto"
      style="animation: toastSlideDown 0.25s ease-out;"
    >
      <div class="bg-ink-900 text-ink-100 rounded-xl px-4 py-2.5 shadow-xl flex items-center gap-3 font-serif text-xs">
        <div class="w-6 h-6 rounded-full bg-accent-orange/20 flex items-center justify-center text-accent-orange text-[9px] font-bold shrink-0">
          {String.first(@toast.actor_username) |> String.upcase()}
        </div>
        <p class="m-0 flex-1 min-w-0 truncate">
          <span class="font-bold text-accent-orange">@{@toast.actor_username}</span>
          <span class="text-ink-300">{action_text(@toast.action, @toast.metadata)}</span>
        </p>
      </div>
      <style>
        @keyframes toastSlideDown {
          from { opacity: 0; transform: translate(-50%, -100%); }
          to { opacity: 1; transform: translate(-50%, 0); }
        }
      </style>
    </div>
    """
  end

  defp action_text(:liked_step, %{step_name: name}), do: " curtiu #{name}"
  defp action_text(:followed_user, %{target_username: name}), do: " seguiu @#{name}"
  defp action_text(:created_sequence, %{sequence_name: name}), do: " criou #{name}"
  defp action_text(:suggested_step, %{step_name: name}), do: " sugeriu #{name}"
  defp action_text(_, _), do: " fez algo novo"
end
