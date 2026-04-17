defmodule OGrupoDeEstudos.Engagement.Badges do
  @moduledoc """
  Computes gamification badges from engagement metrics.
  No persistence — calculated on-demand from COUNT queries.
  Ordered by rank (highest first).
  """

  alias OGrupoDeEstudos.Engagement

  @badges [
    %{key: :estrela, icon: "🌟", name: "Estrela", threshold: 25, metric: :likes_received},
    %{key: :popular, icon: "❤️", name: "Popular", threshold: 10, metric: :likes_received},
    %{key: :voz_ativa, icon: "🎤", name: "Voz Ativa", threshold: 15, metric: :comments_count},
    %{key: :comentarista, icon: "💬", name: "Comentarista", threshold: 5, metric: :comments_count},
    %{key: :curador, icon: "⭐", name: "Curador", threshold: 15, metric: :likes_given},
    %{key: :explorador, icon: "🧭", name: "Explorador", threshold: 5, metric: :likes_given}
  ]

  def all_badges, do: @badges

  @doc "Returns all badges with earned/progress for a user."
  def compute(user_id) do
    metrics = fetch_metrics(user_id)

    Enum.map(@badges, fn badge ->
      current = Map.get(metrics, badge.metric, 0)

      Map.merge(badge, %{
        earned: current >= badge.threshold,
        current: current,
        progress: min(current / badge.threshold, 1.0)
      })
    end)
  end

  @doc "Returns the highest-rank earned badge, or nil."
  def primary(user_id) do
    user_id |> compute() |> Enum.find(& &1.earned)
  end

  defp fetch_metrics(user_id) do
    %{
      likes_given: Engagement.count_likes_given(user_id, "step"),
      comments_count: Engagement.count_comments_authored(user_id),
      likes_received: Engagement.total_likes_received(user_id)
    }
  end
end
