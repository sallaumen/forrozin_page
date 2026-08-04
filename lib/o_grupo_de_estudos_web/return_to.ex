defmodule OGrupoDeEstudosWeb.ReturnTo do
  @moduledoc """
  Validation of post-login destinations.

  A `return_to` reaches us through the query string, so it is attacker
  controlled: only paths inside the app are accepted. Anything else
  (absolute url, protocol-relative `//host`, backslash trick) is discarded,
  which keeps the login page from becoming an open redirect.
  """

  @doc "The path when it points inside the app, `default` (nil) otherwise."
  @spec safe_path(term(), String.t() | nil) :: String.t() | nil
  def safe_path(value, default \\ nil)

  def safe_path("/" <> _rest = path, default) do
    if local_path?(path), do: path, else: default
  end

  def safe_path(_value, default), do: default

  defp local_path?("//" <> _rest), do: false
  defp local_path?("/\\" <> _rest), do: false
  defp local_path?(path), do: String.trim(path) != ""
end
