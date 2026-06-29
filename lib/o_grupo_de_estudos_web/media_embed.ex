defmodule OGrupoDeEstudosWeb.MediaEmbed do
  @moduledoc """
  Resolve a URL de um link em informação de embed (cálculo puro, sem I/O).

  Reconhece os provedores que sabemos embutir num `<iframe>` — vídeo do
  YouTube, YouTube Shorts e posts/reels do Instagram — e devolve a URL de
  embed, um rótulo amigável e o formato (`shape`) que a UI usa para escolher
  o aspect ratio. O que não dá para embutir vira `:external`, ainda com um
  rótulo (host) para o link continuar clicável.

  O embed do Instagram usa o endpoint `/embed` (iframe puro), que NÃO depende
  do `embed.js` deles — assim a CSP de scripts continua restritiva. Os hosts
  de embed precisam estar liberados em `frame-src`
  (ver `Plugs.ContentSecurityPolicy`).
  """

  @yt_hosts ~w(www.youtube.com youtube.com m.youtube.com)
  @ig_hosts ~w(www.instagram.com instagram.com)

  @type shape :: :wide | :tall | :portrait
  @type t :: %{
          kind: :embed | :external,
          embed_url: String.t() | nil,
          label: String.t(),
          shape: shape() | nil
        }

  @doc "Resolve `url` em `t()`. Strings inválidas/`nil` viram `:external`."
  @spec resolve(String.t() | nil) :: t()
  def resolve(url) when is_binary(url), do: url |> URI.parse() |> classify()
  def resolve(_), do: external("Link")

  defp classify(%URI{host: host, path: "/watch", query: query}) when host in @yt_hosts do
    case URI.decode_query(query || "") do
      %{"v" => id} when id != "" -> youtube(id, "YouTube", :wide)
      _ -> external("YouTube")
    end
  end

  defp classify(%URI{host: host, path: "/shorts/" <> rest}) when host in @yt_hosts,
    do: youtube_from(rest, "YouTube Shorts", :tall)

  defp classify(%URI{host: "youtu.be", path: path}) when is_binary(path),
    do: youtube_from(String.trim_leading(path, "/"), "YouTube", :wide)

  defp classify(%URI{host: host, path: "/p/" <> rest}) when host in @ig_hosts,
    do: instagram("p", rest)

  defp classify(%URI{host: host, path: "/reel/" <> rest}) when host in @ig_hosts,
    do: instagram("reel", rest)

  defp classify(%URI{host: host, path: "/reels/" <> rest}) when host in @ig_hosts,
    do: instagram("reel", rest)

  defp classify(%URI{host: host, path: "/tv/" <> rest}) when host in @ig_hosts,
    do: instagram("tv", rest)

  defp classify(%URI{host: host}) when host in @ig_hosts, do: external("Instagram")
  defp classify(%URI{host: host}) when is_binary(host), do: external(host_label(host))
  defp classify(_), do: external("Link")

  defp youtube_from(rest, label, shape) do
    case first_segment(rest) do
      "" -> external(label)
      id -> youtube(id, label, shape)
    end
  end

  defp youtube(id, label, shape),
    do: %{
      kind: :embed,
      embed_url: "https://www.youtube.com/embed/#{id}",
      label: label,
      shape: shape
    }

  defp instagram(type, rest) do
    case first_segment(rest) do
      "" ->
        external("Instagram")

      code ->
        %{
          kind: :embed,
          embed_url: "https://www.instagram.com/#{type}/#{code}/embed",
          label: "Instagram",
          shape: :portrait
        }
    end
  end

  defp external(label), do: %{kind: :external, embed_url: nil, label: label, shape: nil}

  defp first_segment(path), do: path |> String.split(["/", "?"], parts: 2) |> List.first()

  defp host_label(host), do: String.replace_prefix(host, "www.", "")
end
