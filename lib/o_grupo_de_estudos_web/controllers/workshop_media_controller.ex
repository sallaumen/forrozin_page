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

  # O poster e um quadro do video: passa exatamente pela mesma permissao, senao
  # daria para reconstruir a aula em thumbnails sem pagar por ela.
  @poster_type "image/jpeg"

  def show(conn, %{"id" => media_id}) do
    case autorizada(conn, media_id) do
      {:ok, media} -> entregar(conn, Workshops.private_media_path(media), media.content_type)
      :error -> nao_encontrado(conn)
    end
  end

  def poster(conn, %{"id" => media_id}) do
    with {:ok, media} <- autorizada(conn, media_id),
         caminho when is_binary(caminho) <- Workshops.poster_path(media) do
      entregar(conn, caminho, @poster_type)
    else
      _sem_poster_ou_sem_permissao -> nao_encontrado(conn)
    end
  end

  defp autorizada(conn, media_id) do
    with %{} = media <- Workshops.get_media(media_id),
         %{} = workshop <- Workshops.get_workshop(media.workshop_id),
         true <- is_nil(media.deleted_at),
         true <- Workshops.can_see_media?(workshop, conn.assigns[:current_user]) do
      {:ok, media}
    else
      _recusado -> :error
    end
  end

  defp entregar(conn, caminho, content_type) do
    conn
    # Conteudo pago: nunca em cache compartilhado.
    |> put_resp_header("cache-control", "private, no-store")
    |> put_resp_header("x-content-type-options", "nosniff")
    # Sem charset: o arquivo e binario, e "image/png; charset=utf-8" e besteira.
    |> put_resp_content_type(content_type, nil)
    |> send_file(200, caminho)
  end

  defp nao_encontrado(conn), do: conn |> put_status(:not_found) |> text("Não encontrado")
end
