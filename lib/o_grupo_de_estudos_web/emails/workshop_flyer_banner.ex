defmodule OGrupoDeEstudosWeb.Emails.WorkshopFlyerBanner do
  @moduledoc """
  Flyer row shared by workshop emails.

  The image goes exactly as the workshop page shows it: a full url (R2
  public bucket) as it is, a local upload path behind the app origin,
  since an email client resolves nothing relative. Never the og-image
  route: for R2-hosted flyers it falls back to the app icon, which once
  posed as a giant logo in a reminder batch. No flyer, no row.
  """

  @doc "Table row with the flyer image linking to `link`, or empty."
  def banner_row(%{flyer_path: nil}, _link), do: ""

  def banner_row(workshop, link) do
    """
    <tr><td style="background:#faf8f4;padding:24px 28px 0;" align="center">
      <a href="#{link}" style="text-decoration:none;">
        <img src="#{absolute_flyer_url(workshop.flyer_path)}" width="260" alt="#{workshop.title}"
             style="display:block;width:260px;max-width:100%;border-radius:12px;border:1px solid #e8e0d4;" />
      </a>
    </td></tr>
    """
  end

  defp absolute_flyer_url("http" <> _rest = full_url), do: full_url
  defp absolute_flyer_url(local_path), do: OGrupoDeEstudosWeb.Endpoint.url() <> local_path
end
