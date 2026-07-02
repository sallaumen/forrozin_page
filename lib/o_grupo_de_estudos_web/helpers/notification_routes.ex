defmodule OGrupoDeEstudosWeb.Helpers.NotificationRoutes do
  @moduledoc """
  Pure path/label resolution for notifications (raw or grouped entries).

  Step and profile targets come pre-batched from
  `Engagement.notification_targets/1` — render layers never query.
  """

  use Phoenix.VerifiedRoutes,
    endpoint: OGrupoDeEstudosWeb.Endpoint,
    router: OGrupoDeEstudosWeb.Router

  @type targets :: %{steps: %{optional(binary()) => map()}, users: %{optional(binary()) => map()}}

  @spec path(map(), targets()) :: String.t()
  def path(%{action: "study_nudge", target_type: "study_link", target_id: id}, _targets),
    do: ~p"/study/shared/#{id}"

  def path(%{action: "shared_note_updated", target_type: "study_link", target_id: id}, _targets),
    do: ~p"/study/shared/#{id}"

  def path(%{parent_type: "study_link"}, _targets), do: ~p"/study"

  def path(%{parent_type: "step", parent_id: id}, %{steps: steps}) do
    case steps[id] do
      nil -> ~p"/collection"
      %{code: code} -> ~p"/steps/#{code}"
    end
  end

  def path(%{parent_type: "profile", parent_id: id}, %{users: users}) do
    case users[id] do
      nil -> ~p"/collection"
      %{username: username} -> ~p"/users/#{username}"
    end
  end

  def path(%{parent_type: "sequence"}, _targets), do: ~p"/sequence"

  def path(_notification, _targets), do: ~p"/collection"

  @spec step_name(map(), targets()) :: String.t() | nil
  def step_name(%{parent_type: "step", parent_id: id}, %{steps: steps}) when not is_nil(id) do
    case steps[id] do
      nil -> nil
      %{name: name} -> name
    end
  end

  def step_name(_notification, _targets), do: nil
end
