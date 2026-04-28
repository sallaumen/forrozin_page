defmodule OGrupoDeEstudos.Admin.ErrorLogger do
  @moduledoc """
  Captures error/warning logs and persists them to the error_logs table.
  Runs as a :logger handler (Erlang logger, not Elixir Logger backend).

  Only captures :error level by default. Debounces identical messages
  to avoid flooding the DB during cascading failures.
  """

  alias OGrupoDeEstudos.Admin.ErrorLog
  alias OGrupoDeEstudos.Repo

  @debounce_ms 5_000

  @dialyzer {:nowarn_function, install: 0}
  def install do
    :logger.add_handler(:error_db_handler, __MODULE__, %{
      level: :error,
      last_msg: nil,
      last_time: 0
    })
  end

  # :logger handler callback
  def log(%{level: level, msg: msg, meta: meta}, config) do
    message = format_message(msg)
    now = System.monotonic_time(:millisecond)

    # Debounce: skip if same message within 5 seconds
    if message == config.last_msg and now - config.last_time < @debounce_ms do
      config
    else
      Task.start(fn ->
        try do
          Repo.insert(%ErrorLog{
            level: to_string(level),
            message: String.slice(message, 0, 5000),
            source: extract_source(meta),
            stacktrace: extract_stacktrace(meta),
            metadata: extract_metadata(meta)
          })
        rescue
          _ -> :ok
        end
      end)

      %{config | last_msg: message, last_time: now}
    end
  end

  defp format_message({:string, msg}), do: IO.iodata_to_binary(msg)
  defp format_message({:report, report}), do: inspect(report, limit: 500)
  defp format_message(other), do: inspect(other, limit: 500)

  defp extract_source(meta) do
    cond do
      Map.has_key?(meta, :mfa) ->
        {m, f, a} = meta.mfa
        "#{inspect(m)}.#{f}/#{a}"

      Map.has_key?(meta, :module) ->
        inspect(meta.module)

      true ->
        nil
    end
  end

  defp extract_stacktrace(meta) do
    case Map.get(meta, :stacktrace) do
      nil -> nil
      [] -> nil
      st -> Exception.format_stacktrace(st) |> String.slice(0, 5000)
    end
  rescue
    _ -> nil
  end

  defp extract_metadata(meta) do
    meta
    |> Map.take([:request_id, :pid, :module, :function, :line])
    |> Map.new(fn {k, v} -> {k, inspect(v)} end)
  rescue
    _ -> %{}
  end
end
