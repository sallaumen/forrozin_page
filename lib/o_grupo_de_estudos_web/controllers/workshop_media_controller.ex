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

  # O content_type gravado na linha veio do navegador de quem subiu o arquivo.
  # Servir qualquer coisa fora desta lista abriria XSS armazenado: um
  # "image/svg+xml" forjado executa script na origem do site quando aberto
  # direto pela URL. Fora da lista, o arquivo desce como binario generico.
  @tipos_seguros ~w(image/jpeg image/png image/webp video/mp4 video/quicktime)

  def show(conn, %{"id" => media_id}) do
    case autorizada(conn, media_id) do
      {:ok, media} -> entregar(conn, media)
      :error -> nao_encontrado(conn)
    end
  end

  def poster(conn, %{"id" => media_id}) do
    case autorizada(conn, media_id) do
      {:ok, media} -> entregar_poster(conn, media)
      :error -> nao_encontrado(conn)
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

  defp entregar(conn, media) do
    conn
    |> put_resp_content_type(tipo_seguro(media.content_type), nil)
    |> responder(Workshops.serve_media(media))
  end

  # O poster e um quadro do video: mesma permissao da midia, senao daria para
  # reconstruir a aula em thumbnails sem pagar por ela. Sempre JPEG: quem o
  # gerou foi o transcode, nunca o navegador de quem subiu.
  defp entregar_poster(conn, media) do
    conn
    |> put_resp_content_type("image/jpeg", nil)
    |> responder(Workshops.serve_poster(media))
  end

  # A porta de storage decide o como: arquivo local sai por sendfile do
  # kernel; provider externo sai por URL assinada de vida curta.
  #
  # O skip e falso-positivo do sobelow: ele marca qualquer variavel no
  # send_file, mas este caminho vem de `ObjectStorage.serve/1` com chave
  # opaca gerada pelo servidor. Input de usuario e so o id, resolvido por
  # `autorizada/2` via banco.
  # sobelow_skip ["Traversal.SendFile"]
  defp responder(conn, {:file, caminho}) do
    conn |> cabecalhos_de_midia() |> send_file(200, caminho)
  end

  defp responder(conn, {:redirect, url}), do: redirect(conn, external: url)
  defp responder(conn, {:error, :not_found}), do: nao_encontrado(conn)

  defp cabecalhos_de_midia(conn) do
    conn
    # Conteudo pago: nunca em cache compartilhado.
    |> put_resp_header("cache-control", "private, no-store")
    |> put_resp_header("x-content-type-options", "nosniff")
  end

  # Sem charset em nenhum caso: o arquivo e binario, e "image/png;
  # charset=utf-8" e besteira.
  defp tipo_seguro(tipo) when tipo in @tipos_seguros, do: tipo
  defp tipo_seguro(_desconfiado), do: "application/octet-stream"

  defp nao_encontrado(conn), do: conn |> put_status(:not_found) |> text("Não encontrado")
end
