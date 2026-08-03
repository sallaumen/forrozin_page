defmodule OGrupoDeEstudosWeb.Plugs.UploadsStatic do
  @moduledoc """
  Serves user-uploaded files from the configured uploads path.

  In production (Fly.io), files live on a persistent volume at `/app/uploads`.
  In development, files live at `priv/static/uploads`.

  The path is resolved at runtime via application config:
    config :o_grupo_de_estudos, :uploads_path, "/app/uploads"

  ## Allowlist

  Este plug roda ANTES de `Plug.Session` no endpoint, entao nao existe usuario
  para consultar: tudo que ele serve e publico por construcao. Por isso o
  `:only` lista o que pode ser publico, em vez de o que nao pode. Diretorio
  novo no volume (midia de workshop, por exemplo) nao vaza sozinho: ou entra
  aqui de proposito, ou e servido por um controller que checa permissao.
  """

  @behaviour Plug

  # Conteudo que e publico por natureza. Qualquer coisa fora daqui exige
  # autorizacao e portanto nao passa por este plug.
  # Flyer e material de divulgacao: existe para circular. Avatar idem. Tudo
  # que for restrito (midia paga de workshop) fica fora daqui e passa por
  # controller com permissao.
  @public_dirs ["avatars", "flyers"]

  @impl true
  def init(_opts), do: []

  @impl true
  def call(%Plug.Conn{request_path: "/uploads/" <> _rest} = conn, _opts) do
    path = uploads_path()

    opts =
      Plug.Static.init(
        at: "/uploads",
        from: path,
        gzip: false,
        only: @public_dirs
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
