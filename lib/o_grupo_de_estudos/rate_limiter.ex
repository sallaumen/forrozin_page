defmodule OGrupoDeEstudos.RateLimiter do
  @moduledoc """
  Simple in-memory rate limiter using ETS.

  Tracks action counts per user with automatic expiry.
  No external dependencies, no database overhead.

  Usage:
      case RateLimiter.check("comment", user_id, limit: 3, window_seconds: 30) do
        :ok -> # proceed
        {:error, :rate_limited} -> # reject
      end
  """

  use GenServer

  @table :rate_limiter
  @cleanup_interval :timer.minutes(5)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Check if the action is allowed for this user.

  Options:
  - `limit` — max actions in the window (default: 5)
  - `window_seconds` — time window in seconds (default: 60)
  """
  def check(action, user_id, opts \\ []) do
    # Disabled in test environment
    if Application.get_env(:o_grupo_de_estudos, :env) == :test, do: :ok, else: do_check(action, user_id, opts)
  end

  defp do_check(action, user_id, opts) do
    limit = Keyword.get(opts, :limit, 5)
    window = Keyword.get(opts, :window_seconds, 60)
    key = {action, user_id}
    now = System.monotonic_time(:second)
    cutoff = now - window

    # Get existing entries, filter expired
    entries =
      case :ets.lookup(@table, key) do
        [{^key, timestamps}] -> Enum.filter(timestamps, &(&1 > cutoff))
        [] -> []
      end

    if length(entries) >= limit do
      {:error, :rate_limited}
    else
      :ets.insert(@table, {key, [now | entries]})
      :ok
    end
  end

  # ── GenServer callbacks ──────────────────────────────────────────────

  @impl true
  def init(_) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true, write_concurrency: true])
    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.monotonic_time(:second)
    cutoff = now - 300

    :ets.foldl(
      fn {key, timestamps}, acc ->
        valid = Enum.filter(timestamps, &(&1 > cutoff))
        if valid == [], do: :ets.delete(@table, key), else: :ets.insert(@table, {key, valid})
        acc
      end,
      nil,
      @table
    )

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
end
