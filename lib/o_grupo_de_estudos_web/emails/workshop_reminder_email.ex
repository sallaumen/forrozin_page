defmodule OGrupoDeEstudosWeb.Emails.WorkshopReminderEmail do
  @moduledoc "Day-before email: there is a workshop tomorrow."

  alias Swoosh.Email

  use OGrupoDeEstudosWeb, :verified_routes

  import OGrupoDeEstudosWeb.WorkshopComponents, only: [schedule_label: 1]

  @sender {"O Grupo de Estudos", "noreply@ogrupodeestudos.com.br"}

  @doc "Builds the day-before notice for one person and one workshop."
  def new(user, workshop) do
    nome = user.name || user.username
    link = url(~p"/workshops/#{workshop.slug}")

    Email.new()
    |> Email.to({nome, user.email})
    |> Email.from(@sender)
    |> Email.subject("Amanhã tem #{workshop.title}")
    |> Email.html_body(html(nome, workshop, link))
    |> Email.text_body(texto(nome, workshop, link))
  end

  defp html(nome, workshop, link) do
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
            <tr><td style="background:#faf8f4;padding:28px;border-radius:0 0 12px 12px;">
              <p style="margin:0 0 12px;font-size:16px;color:#2b1c10;">Oi, #{nome}!</p>
              <p style="margin:0 0 16px;font-size:15px;line-height:1.6;color:#4a3627;">
                Amanhã tem <strong>#{workshop.title}</strong>.
              </p>
              <p style="margin:0 0 20px;font-size:14px;line-height:1.6;color:#6b5544;">
                #{schedule_label(workshop)}#{local(workshop)}
              </p>
              <a href="#{link}" style="display:inline-block;background:#c8763c;color:#fff;text-decoration:none;padding:12px 24px;border-radius:999px;font-size:14px;font-weight:600;">
                Ver o workshop
              </a>
              <p style="margin:20px 0 0;font-size:12px;color:#8a7462;">
                Bom treino, e até amanhã.
              </p>
            </td></tr>
          </table>
        </td></tr>
      </table>
    </body>
    </html>
    """
  end

  defp texto(nome, workshop, link) do
    """
    Oi, #{nome}!

    Amanhã tem #{workshop.title}.
    #{schedule_label(workshop)}#{local(workshop)}

    #{link}

    Bom treino, e até amanhã.
    """
  end

  defp local(%{location: nil}), do: ""
  defp local(%{location: ""}), do: ""
  defp local(%{location: location}), do: " · #{location}"
end
