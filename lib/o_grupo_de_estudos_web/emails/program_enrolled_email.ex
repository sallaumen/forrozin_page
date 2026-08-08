defmodule OGrupoDeEstudosWeb.Emails.ProgramEnrolledEmail do
  @moduledoc """
  Enrollment confirmation for a program: one email listing every class
  covered, whether by the package or by hand-picked workshops.
  """

  alias Swoosh.Email

  use OGrupoDeEstudosWeb, :verified_routes

  import OGrupoDeEstudosWeb.Emails.WorkshopFlyerBanner, only: [banner_row: 2]
  import OGrupoDeEstudosWeb.WorkshopComponents, only: [schedule_label: 1]

  @sender {"O Grupo de Estudos", "noreply@ogrupodeestudos.com.br"}

  @doc "Builds the confirmation listing the covered workshops."
  def new(user, program, workshops) do
    name = user.name || user.username
    first_name = name |> String.split() |> hd()
    link = url(~p"/programs/#{program.slug}")

    Email.new()
    |> Email.to({name, user.email})
    |> Email.from(@sender)
    |> Email.subject("Inscrição confirmada: #{program.title}")
    |> Email.html_body(html(first_name, program, workshops, link))
    |> Email.text_body(text(first_name, program, workshops, link))
  end

  defp html(name, program, workshops, link) do
    """
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
    <body style="margin:0;padding:0;background:#f0ece4;font-family:Georgia,'Times New Roman',serif;">
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0ece4;padding:32px 16px;">
        <tr><td align="center">
          <table width="520" cellpadding="0" cellspacing="0" style="max-width:520px;width:100%;">
            <tr><td style="background:#1a0e05;padding:20px 28px;border-radius:12px 12px 0 0;" align="center">
              <p style="margin:0;font-size:11px;font-weight:700;letter-spacing:3px;text-transform:uppercase;color:#d4a574;">
                O Grupo de Estudos
              </p>
            </td></tr>
            #{banner_row(program, link)}
            <tr><td style="background:#faf8f4;padding:28px;border-radius:0 0 12px 12px;">
              <p style="margin:0 0 12px;font-size:16px;color:#2b1c10;">Oi, #{name}!</p>
              <p style="margin:0 0 16px;font-size:15px;line-height:1.6;color:#4a3627;">
                Sua inscrição no <strong>#{program.title}</strong> tá confirmada. Suas aulas:
              </p>

              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:20px;background:#ffffff;border:1px solid #e8e0d4;border-radius:10px;">
                #{workshop_rows(workshops)}
              </table>

              <a href="#{link}" style="display:inline-block;background:#c8763c;color:#fff;text-decoration:none;padding:12px 24px;border-radius:999px;font-size:14px;font-weight:600;">
                Ver a programação
              </a>
              <p style="margin:20px 0 0;font-size:12px;color:#8a7462;">
                Nos vemos lá!
              </p>
            </td></tr>
          </table>
        </td></tr>
      </table>
    </body>
    </html>
    """
  end

  defp workshop_rows(workshops) do
    Enum.map_join(workshops, "\n", fn workshop ->
      """
      <tr><td style="padding:12px 16px;font-size:13.5px;color:#4a3627;border-bottom:1px solid #f0ece4;">
        <strong>#{workshop.title}</strong><br />
        <span style="color:#6b5544;">#{schedule_label(workshop)}</span>
      </td></tr>
      """
    end)
  end

  defp text(name, program, workshops, link) do
    lines =
      Enum.map_join(workshops, "\n", fn workshop ->
        "- #{workshop.title}: #{schedule_label(workshop)}"
      end)

    """
    Oi, #{name}!

    Sua inscrição no #{program.title} tá confirmada. Suas aulas:

    #{lines}

    #{link}

    Nos vemos lá!
    """
  end
end
