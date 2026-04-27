defmodule OGrupoDeEstudosWeb.Plugs.UploadsStatic do
  @moduledoc """
  Serves user-uploaded files from the configured uploads path.

  In production (Fly.io), files live on a persistent volume at `/app/uploads`.
  In development, files live at `priv/static/uploads`.

  The path is resolved at runtime via application config:
    config :o_grupo_de_estudos, :uploads_path, "/app/uploads"
  """

  @behaviour Plug

  @impl true
  def init(_opts), do: []

  @impl true
  def call(%Plug.Conn{request_path: "/uploads/" <> _rest} = conn, _opts) do
    path = uploads_path()

    opts =
      Plug.Static.init(
        at: "/uploads",
        from: path,
        gzip: false
      )

    Plug.Static.call(conn, opts)
  end

  def call(conn, _opts), do: conn

  defp uploads_path do
    Application.get_env(:o_grupo_de_estudos, :uploads_path, default_path())
  end

  defp default_path do
    if File.dir?("/app/uploads"),
      do: "/app/uploads",
      else: Path.join(:code.priv_dir(:o_grupo_de_estudos), "static/uploads")
  end
end
