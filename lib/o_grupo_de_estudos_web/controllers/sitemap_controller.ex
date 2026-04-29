defmodule OGrupoDeEstudosWeb.SitemapController do
  @moduledoc """
  Generates a dynamic sitemap.xml with all public-facing pages.
  Updates automatically as new steps and users are added.
  """

  use OGrupoDeEstudosWeb, :controller

  alias OGrupoDeEstudos.Encyclopedia
  alias OGrupoDeEstudos.Accounts

  def index(conn, _params) do
    steps = Encyclopedia.list_all_step_codes()
    users = Accounts.list_all_usernames()

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, build_sitemap(steps, users))
  end

  defp build_sitemap(steps, users) do
    base = "https://ogrupodeestudos.com.br"

    static_urls =
      [
        {base, "1.0", "daily"},
        {"#{base}/login", "0.5", "monthly"},
        {"#{base}/signup", "0.5", "monthly"},
        {"#{base}/about", "0.3", "monthly"}
      ]

    step_urls =
      Enum.map(steps, fn code ->
        {"#{base}/steps/#{code}", "0.8", "weekly"}
      end)

    user_urls =
      Enum.map(users, fn username ->
        {"#{base}/users/#{username}", "0.6", "weekly"}
      end)

    urls = static_urls ++ step_urls ++ user_urls

    entries =
      Enum.map(urls, fn {loc, priority, changefreq} ->
        """
        <url>
          <loc>#{loc}</loc>
          <priority>#{priority}</priority>
          <changefreq>#{changefreq}</changefreq>
        </url>
        """
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{Enum.join(entries)}
    </urlset>
    """
  end
end
