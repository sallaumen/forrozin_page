defmodule OGrupoDeEstudosWeb.Emails.WorkshopEnrolledEmail do
  @moduledoc """
  Enrollment confirmation for a single workshop.

  One template on purpose: it is a receipt with the practical details
  (when, where, price and how to pay), plus the flyer.
  """

  alias Swoosh.Email

  use OGrupoDeEstudosWeb, :verified_routes

  import OGrupoDeEstudosWeb.Emails.WorkshopFlyerBanner, only: [banner_row: 2]
  import OGrupoDeEstudosWeb.WorkshopComponents, only: [schedule_label: 1, price_label: 1]

  @sender {"O Grupo de Estudos", "noreply@ogrupodeestudos.com.br"}

  @doc "Builds the confirmation with the workshop details."
  def new(user, workshop) do
    name = user.name || user.username
    first_name = name |> String.split() |> hd()
    link = url(~p"/workshops/#{workshop.slug}")

    Email.new()
    |> Email.to({name, user.email})
    |> Email.from(@sender)
    |> Email.subject("Inscrição confirmada: #{workshop.title}")
    |> Email.html_body(html(first_name, workshop, link))
    |> Email.text_body(text(first_name, workshop, link))
  end

  defp payment_line(%{price_cents: cents} = workshop) when is_integer(cents) and cents > 0 do
    case workshop.payment_info do
      nil -> price_label(workshop)
      "" -> price_label(workshop)
      payment_info -> "#{price_label(workshop)} · #{payment_info}"
    end
  end

  defp payment_line(workshop), do: price_label(workshop)

  defp html(name, workshop, link) do
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
            #{banner_row(workshop, link)}
            <tr><td style="background:#faf8f4;padding:28px;border-radius:0 0 12px 12px;">
              <p style="margin:0 0 12px;font-size:16px;color:#2b1c10;">Oi, #{name}!</p>
              <p style="margin:0 0 16px;font-size:15px;line-height:1.6;color:#4a3627;">
                Sua inscrição no <strong>#{workshop.title}</strong> tá confirmada. Anota aí:
              </p>

              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:20px;background:#ffffff;border:1px solid #e8e0d4;border-radius:10px;">
                <tr><td style="padding:12px 16px;font-size:13.5px;color:#4a3627;border-bottom:1px solid #f0ece4;">
                  <strong>Quando</strong>: #{schedule_label(workshop)}
                </td></tr>
                #{location_row(workshop)}
                <tr><td style="padding:12px 16px;font-size:13.5px;color:#4a3627;">
                  <strong>Valor</strong>: #{payment_line(workshop)}
                </td></tr>
              </table>

              <a href="#{link}" style="display:inline-block;background:#c8763c;color:#fff;text-decoration:none;padding:12px 24px;border-radius:999px;font-size:14px;font-weight:600;">
                Ver o workshop
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

  defp location_row(%{location: nil}), do: ""
  defp location_row(%{location: ""}), do: ""

  defp location_row(%{location: location}) do
    """
    <tr><td style="padding:12px 16px;font-size:13.5px;color:#4a3627;border-bottom:1px solid #f0ece4;">
      <strong>Onde</strong>: #{location}
    </td></tr>
    """
  end

  defp text(name, workshop, link) do
    """
    Oi, #{name}!

    Sua inscrição no #{workshop.title} tá confirmada. Anota aí:

    Quando: #{schedule_label(workshop)}#{text_location(workshop)}
    Valor: #{payment_line(workshop)}

    #{link}

    Nos vemos lá!
    """
  end

  defp text_location(%{location: nil}), do: ""
  defp text_location(%{location: ""}), do: ""
  defp text_location(%{location: location}), do: "\nOnde: #{location}"
end
