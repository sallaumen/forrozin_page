defmodule OGrupoDeEstudosWeb.Helpers.RateLimit do
  @moduledoc """
  Helpers for handling rate-limited responses in LiveViews.
  """

  import Phoenix.LiveView, only: [put_flash: 3]

  @rate_limit_message "Calma! Muitas ações seguidas. Espere alguns segundinhos."

  @doc """
  Checks if a context function returned a rate limit error.
  If so, adds a flash warning to the socket.

  Usage:
      result = Engagement.toggle_like(user_id, type, id)
      socket = maybe_flash_rate_limit(socket, result)
  """
  def maybe_flash_rate_limit(socket, {:error, :rate_limited}) do
    put_flash(socket, :error, @rate_limit_message)
  end

  def maybe_flash_rate_limit(socket, _other_result), do: socket
end
