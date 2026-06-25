defmodule OGrupoDeEstudosWeb.Helpers.NotificationPresenter do
  @moduledoc """
  Pure presentation helpers for grouped notifications.

  Shared between `NotificationsLive` (full page) and `TopNav` (dropdown) so the
  wording stays consistent. Works on the maps produced by
  `OGrupoDeEstudos.Engagement.Notifications.Grouper`.
  """

  @doc """
  Labels the actors of a grouped notification.

  One actor returns the name; several return "Primeiro e mais N".
  """
  def actors_label(%{actors_data: [actor | rest]}) do
    name = actor.name || actor.username || "Alguém"

    case rest do
      [] -> name
      others -> "#{name} e mais #{length(others)}"
    end
  end

  def actors_label(_), do: "Alguém"

  @doc "Uppercased first letter of the primary actor, for avatar placeholders."
  def notification_initial(%{actors_data: [actor | _]}) do
    (actor.name || actor.username || "?")
    |> String.first()
    |> String.upcase()
  end

  def notification_initial(_), do: "?"

  @doc """
  The action phrase, agreeing in number with the grouped actor count.

  Accepts a `:count` key; defaults to singular when absent.
  """
  def action_text(%{action: action, count: count}), do: action_phrase(action, count > 1)
  def action_text(%{action: action}), do: action_phrase(action, false)

  defp action_phrase("liked_comment", false), do: " curtiu seu comentário"
  defp action_phrase("liked_comment", true), do: " curtiram seu comentário"
  defp action_phrase("replied_comment", false), do: " respondeu ao seu comentário"
  defp action_phrase("replied_comment", true), do: " responderam ao seu comentário"
  defp action_phrase("liked_step", false), do: " curtiu o passo"
  defp action_phrase("liked_step", true), do: " curtiram o passo"
  defp action_phrase("liked_sequence", false), do: " curtiu a sequência"
  defp action_phrase("liked_sequence", true), do: " curtiram a sequência"
  defp action_phrase("followed_user", false), do: " começou a te seguir"
  defp action_phrase("followed_user", true), do: " começaram a te seguir"
  defp action_phrase("suggestion_created", _), do: " enviou uma sugestão"
  defp action_phrase("suggestion_approved", _), do: " aprovou sua sugestão ✓"
  defp action_phrase("suggestion_rejected", _), do: " rejeitou sua sugestão"
  defp action_phrase("study_request", _), do: " quer estudar com você"
  defp action_phrase("study_accepted", _), do: " aceitou seu pedido de estudo"
  defp action_phrase("shared_note_updated", _), do: " escreveu no diário compartilhado"
  defp action_phrase("study_nudge", _), do: " mandou um lembrete: hora de escrever no diário!"
  defp action_phrase(_, _), do: " interagiu"

  @doc "Compact relative time label (agora, 5min, 3h, 2d, 1sem)."
  def time_ago(datetime) do
    diff = NaiveDateTime.diff(NaiveDateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "agora"
      diff < 3_600 -> "#{div(diff, 60)}min"
      diff < 86_400 -> "#{div(diff, 3_600)}h"
      diff < 604_800 -> "#{div(diff, 86_400)}d"
      true -> "#{div(diff, 604_800)}sem"
    end
  end
end
