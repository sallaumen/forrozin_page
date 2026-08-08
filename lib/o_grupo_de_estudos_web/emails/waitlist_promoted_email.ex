defmodule OGrupoDeEstudosWeb.Emails.WaitlistPromotedEmail do
  @moduledoc """
  Good news for whoever left the waitlist into a seat.

  `:capacity_increased` when the organizer opened more seats;
  `:seat_freed` when a cancellation opened one.
  """

  alias Swoosh.Email

  use OGrupoDeEstudosWeb, :verified_routes

  import OGrupoDeEstudosWeb.Emails.WorkshopFlyerBanner, only: [banner_row: 2]
  import OGrupoDeEstudosWeb.WorkshopComponents, only: [schedule_label: 1]

  @sender {"O Grupo de Estudos", "noreply@ogrupodeestudos.com.br"}

  @doc "Builds the promotion notice for the given reason."
  def new(user, workshop, reason) do
    name = user.name || user.username
    first_name = name |> String.split() |> hd()
    link = url(~p"/workshops/#{workshop.slug}")

    Email.new()
    |> Email.to({name, user.email})
    |> Email.from(@sender)
    |> Email.subject(subject(reason, workshop.title))
    |> Email.html_body(html(first_name, workshop, link, opening(reason, workshop.title)))
    |> Email.text_body(text(first_name, workshop, link, opening_text(reason, workshop.title)))
  end

  defp subject(:capacity_increased, title), do: "Boa notícia: você entrou no #{title}!"
  defp subject(:seat_freed, title), do: "Abriu uma vaga e ela era sua: #{title}"

  defp opening(:capacity_increased, title) do
    "O número de vagas aumentou e a sua chegou: você saiu da lista de espera " <>
      "e já está dentro do <strong>#{title}</strong>."
  end

  defp opening(:seat_freed, title) do
    "Abriu uma vaga e ela era sua: você saiu da lista de espera " <>
      "e já está dentro do <strong>#{title}</strong>."
  end

  defp opening_text(:capacity_increased, title) do
    "O número de vagas aumentou e a sua chegou: você saiu da lista de espera " <>
      "e já está dentro do #{title}."
  end

  defp opening_text(:seat_freed, title) do
    "Abriu uma vaga e ela era sua: você saiu da lista de espera " <>
      "e já está dentro do #{title}."
  end

  defp html(name, workshop, link, opening) do
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
                #{opening}
              </p>
              <p style="margin:0 0 20px;font-size:14px;line-height:1.6;color:#6b5544;">
                #{schedule_label(workshop)}#{location(workshop)}
              </p>
              <a href="#{link}" style="display:inline-block;background:#c8763c;color:#fff;text-decoration:none;padding:12px 24px;border-radius:999px;font-size:14px;font-weight:600;">
                Ver o workshop
              </a>
              <p style="margin:20px 0 0;font-size:12px;color:#8a7462;">
                Até lá!
              </p>
            </td></tr>
          </table>
        </td></tr>
      </table>
    </body>
    </html>
    """
  end

  defp text(name, workshop, link, opening_text) do
    """
    Oi, #{name}!

    #{opening_text}
    #{schedule_label(workshop)}#{location(workshop)}

    #{link}

    Até lá!
    """
  end

  defp location(%{location: nil}), do: ""
  defp location(%{location: ""}), do: ""
  defp location(%{location: location}), do: " · #{location}"
end
