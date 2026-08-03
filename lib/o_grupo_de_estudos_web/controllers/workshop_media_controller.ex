defmodule OGrupoDeEstudosWeb.WorkshopMediaController do
  @moduledoc """
  Serve a mídia da galeria só para quem pode ver.

  Existe porque `Plug.Static` roda antes da sessão e não tem como perguntar
  quem é a pessoa. O arquivo mora fora da allowlist do `UploadsStatic`, então
  este é o único caminho até ele.

  `send_file` usa sendfile do kernel via Bandit: o byte não sobe para a BEAM.
  """

  use OGrupoDeEstudosWeb, :controller

  alias OGrupoDeEstudos.Workshops

  def show(conn, %{"id" => media_id}) do
    with %{} = media <- Workshops.get_media(media_id),
         %{} = workshop <- Workshops.get_workshop(media.workshop_id),
         true <- is_nil(media.deleted_at),
         true <- Workshops.can_see_media?(workshop, conn.assigns[:current_user]) do
      entregar(conn, media)
    else
      _recusado -> conn |> put_status(:not_found) |> text("Não encontrado")
    end
  end

  defp entregar(conn, media) do
    conn
    # Conteudo pago: nunca em cache compartilhado.
    |> put_resp_header("cache-control", "private, no-store")
    |> put_resp_header("x-content-type-options", "nosniff")
    # Sem charset: o arquivo e binario, e "image/png; charset=utf-8" e besteira.
    |> put_resp_content_type(media.content_type, nil)
    |> send_file(200, Workshops.private_media_path(media))
  end
end
