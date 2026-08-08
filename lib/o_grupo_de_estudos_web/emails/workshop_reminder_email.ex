defmodule OGrupoDeEstudosWeb.Emails.WorkshopReminderEmail do
  @moduledoc """
  Workshop reminder in five rotating variations per flavor.

  `:tomorrow` is the day-before notice; `:today` covers whoever enrolled
  after the day-before sweep had already run.
  """

  alias Swoosh.Email

  use OGrupoDeEstudosWeb, :verified_routes

  import OGrupoDeEstudosWeb.Emails.WorkshopFlyerBanner, only: [banner_row: 2]
  import OGrupoDeEstudosWeb.WorkshopComponents, only: [schedule_label: 1]

  @sender {"O Grupo de Estudos", "noreply@ogrupodeestudos.com.br"}
  @variation_count 5

  @doc "Builds the reminder with a randomly picked variation."
  def new(user, workshop, flavor),
    do: new(user, workshop, flavor, Enum.random(0..(@variation_count - 1)))

  @doc "Builds the reminder with a specific variation (tests, previews)."
  def new(user, workshop, flavor, variation_index) do
    name = user.name || user.username
    link = url(~p"/workshops/#{workshop.slug}")
    variation = variation(flavor, variation_index, workshop.title)

    Email.new()
    |> Email.to({name, user.email})
    |> Email.from(@sender)
    |> Email.subject(variation.subject)
    |> Email.html_body(html(name, workshop, link, variation))
    |> Email.text_body(text(name, workshop, link, variation))
  end

  defp variation(:tomorrow, 0, title) do
    %{
      subject: "Amanhã tem #{title}",
      opening: "Amanhã tem <strong>#{title}</strong>.",
      opening_text: "Amanhã tem #{title}.",
      closing: "Bom treino, e até amanhã."
    }
  end

  defp variation(:tomorrow, 1, title) do
    %{
      subject: "É amanhã: #{title}",
      opening: "Chegou a véspera: amanhã tem <strong>#{title}</strong>.",
      opening_text: "Chegou a véspera: amanhã tem #{title}.",
      closing: "Descansa hoje que amanhã tem dança."
    }
  end

  defp variation(:tomorrow, 2, title) do
    %{
      subject: "Se prepara: amanhã tem #{title}",
      opening: "Separa a roupa e o sapato: amanhã tem <strong>#{title}</strong>.",
      opening_text: "Separa a roupa e o sapato: amanhã tem #{title}.",
      closing: "Até lá!"
    }
  end

  defp variation(:tomorrow, 3, title) do
    %{
      subject: "Amanhã a gente se vê: #{title}",
      opening: "Passando só pra lembrar: amanhã tem <strong>#{title}</strong>.",
      opening_text: "Passando só pra lembrar: amanhã tem #{title}.",
      closing: "Boa pisada!"
    }
  end

  defp variation(:tomorrow, 4, title) do
    %{
      subject: "Alonga aí, que amanhã tem #{title}",
      opening: "Já pode ir aquecendo: <strong>#{title}</strong> é amanhã.",
      opening_text: "Já pode ir aquecendo: #{title} é amanhã.",
      closing: "Nos vemos na pista."
    }
  end

  defp variation(:today, 0, title) do
    %{
      subject: "É hoje: #{title}",
      opening: "Chegou o dia: hoje tem <strong>#{title}</strong>.",
      opening_text: "Chegou o dia: hoje tem #{title}.",
      closing: "Boa dança, até já!"
    }
  end

  defp variation(:today, 1, title) do
    %{
      subject: "Hoje tem #{title}!",
      opening: "Lembrete rapidinho: hoje tem <strong>#{title}</strong>.",
      opening_text: "Lembrete rapidinho: hoje tem #{title}.",
      closing: "Te esperamos lá."
    }
  end

  defp variation(:today, 2, title) do
    %{
      subject: "#{title} é hoje",
      opening: "O dia chegou: <strong>#{title}</strong> é hoje.",
      opening_text: "O dia chegou: #{title} é hoje.",
      closing: "Até daqui a pouco!"
    }
  end

  defp variation(:today, 3, title) do
    %{
      subject: "Hoje tem dança: #{title}",
      opening: "Bora: hoje tem <strong>#{title}</strong>.",
      opening_text: "Bora: hoje tem #{title}.",
      closing: "Boa aula!"
    }
  end

  defp variation(:today, 4, title) do
    %{
      subject: "Sapato pronto? #{title} é hoje",
      opening: "Hora de calçar o sapato: <strong>#{title}</strong> é hoje.",
      opening_text: "Hora de calçar o sapato: #{title} é hoje.",
      closing: "Nos vemos já já."
    }
  end

  defp html(name, workshop, link, variation) do
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
                #{variation.opening}
              </p>
              <p style="margin:0 0 20px;font-size:14px;line-height:1.6;color:#6b5544;">
                #{schedule_label(workshop)}#{location(workshop)}
              </p>
              <a href="#{link}" style="display:inline-block;background:#c8763c;color:#fff;text-decoration:none;padding:12px 24px;border-radius:999px;font-size:14px;font-weight:600;">
                Ver o workshop
              </a>
              <p style="margin:20px 0 0;font-size:12px;color:#8a7462;">
                #{variation.closing}
              </p>
            </td></tr>
          </table>
        </td></tr>
      </table>
    </body>
    </html>
    """
  end

  defp text(name, workshop, link, variation) do
    """
    Oi, #{name}!

    #{variation.opening_text}
    #{schedule_label(workshop)}#{location(workshop)}

    #{link}

    #{variation.closing}
    """
  end

  defp location(%{location: nil}), do: ""
  defp location(%{location: ""}), do: ""
  defp location(%{location: location}), do: " · #{location}"
end
