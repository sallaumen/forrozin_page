# scripts/script_helper.exs
#
# Shared helpers for all scripts. Source this at the top:
#   Code.require_file("scripts/script_helper.exs")
#
# Provides:
#   - Environment guards (block production)
#   - Structured logging
#   - Dry-run support
#   - Timing

defmodule ScriptHelper do
  @moduledoc """
  Shared utilities for project scripts.

  Usage:
    Code.require_file("scripts/script_helper.exs")
    ScriptHelper.guard_not_production!()
    ScriptHelper.log(:info, "Starting...")
  """

  @doc "Raises if running in production. Call at the top of every destructive script."
  def guard_not_production! do
    if Application.get_env(:o_grupo_de_estudos, :env) == :prod or
         System.get_env("MIX_ENV") == "prod" or
         System.get_env("PHX_HOST") != nil do
      IO.puts("\n\e[31m!!! BLOCKED: This script cannot run in production !!!\e[0m\n")
      System.halt(1)
    end

    log(:ok, "Environment check passed (not production)")
  end

  @doc "Structured log with emoji prefix."
  def log(:info, msg), do: IO.puts("  \e[36mi\e[0m #{msg}")
  def log(:ok, msg), do: IO.puts("  \e[32m✓\e[0m #{msg}")
  def log(:warn, msg), do: IO.puts("  \e[33m!\e[0m #{msg}")
  def log(:error, msg), do: IO.puts("  \e[31m✗\e[0m #{msg}")
  def log(:step, msg), do: IO.puts("\n\e[1m→ #{msg}\e[0m")

  @doc "Times a block and logs duration."
  defmacro timed(label, do: block) do
    quote do
      start = System.monotonic_time(:millisecond)
      result = unquote(block)
      elapsed = System.monotonic_time(:millisecond) - start
      ScriptHelper.log(:ok, "#{unquote(label)} (#{elapsed}ms)")
      result
    end
  end

  @doc "Parses --dry-run flag from System.argv()."
  def dry_run? do
    "--dry-run" in System.argv()
  end
end
