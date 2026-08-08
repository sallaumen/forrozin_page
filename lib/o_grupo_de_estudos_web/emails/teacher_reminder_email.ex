defmodule OGrupoDeEstudosWeb.Emails.TeacherReminderEmail do
  @moduledoc """
  Class summary for whoever teaches or organizes the workshop.

  More sober than the student reminder: schedule, headcount, waitlist and
  the roster, with a link to the manage page. `:tomorrow` goes out the day
  before; `:today` covers workshops that entered the window late.
  """

  alias Swoosh.Email

  use OGrupoDeEstudosWeb, :verified_routes

  import OGrupoDeEstudosWeb.WorkshopComponents, only: [schedule_label: 1]

  @sender {"O Grupo de Estudos", "noreply@ogrupodeestudos.com.br"}

  @doc "Builds the summary for one teacher, with the roster and the numbers."
  def new(teacher, workshop, participants, waitlist_count, flavor: flavor) do
    first_name = teacher.name |> String.split() |> hd()
    manage_link = url(~p"/workshops/#{workshop.slug}/manage")
    count = length(participants)

    Email.new()
    |> Email.to({teacher.name || teacher.username, teacher.email})
    |> Email.from(@sender)
    |> Email.subject("#{day_word(flavor)}: #{workshop.title} · #{count} inscritos")
    |> Email.html_body(
      html(first_name, workshop, participants, waitlist_count, manage_link, flavor)
    )
    |> Email.text_body(
      text(first_name, workshop, participants, waitlist_count, manage_link, flavor)
    )
  end

  defp day_word(:tomorrow), do: "Amanhã"
  defp day_word(:today), do: "Hoje"

  defp day_phrase(:tomorrow), do: "amanhã"
  defp day_phrase(:today), do: "hoje"

  defp headcount(participants, %{capacity: nil}), do: "#{length(participants)}"

  defp headcount(participants, %{capacity: capacity}),
    do: "#{length(participants)} de #{capacity}"

  defp participant_name(%{name: nil, username: username}), do: username
  defp participant_name(%{name: name}), do: name

  defp html(name, workshop, participants, waitlist_count, manage_link, flavor) do
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
              <p style="margin:0 0 12px;font-size:16px;color:#2b1c10;">Oi, #{name}!</p>
              <p style="margin:0 0 16px;font-size:15px;line-height:1.6;color:#4a3627;">
                Resumo da sua aula de #{day_phrase(flavor)}: <strong>#{workshop.title}</strong>.
              </p>

              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:20px;background:#ffffff;border:1px solid #e8e0d4;border-radius:10px;">
                <tr><td style="padding:12px 16px;font-size:13.5px;color:#4a3627;border-bottom:1px solid #f0ece4;">
                  <strong>Quando</strong>: #{schedule_label(workshop)}
                </td></tr>
                #{location_row(workshop)}
                <tr><td style="padding:12px 16px;font-size:13.5px;color:#4a3627;">
                  <strong>Inscritos</strong>: #{headcount(participants, workshop)}#{waitlist_note(waitlist_count)}
                </td></tr>
              </table>

              #{roster(participants)}

              <a href="#{manage_link}" style="display:inline-block;background:#c8763c;color:#fff;text-decoration:none;padding:12px 24px;border-radius:999px;font-size:14px;font-weight:600;">
                Gerenciar inscritos
              </a>
              <p style="margin:20px 0 0;font-size:11.5px;color:#8a7462;">
                Você está recebendo este resumo porque dá aula ou organiza este workshop.
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

  defp waitlist_note(0), do: ""
  defp waitlist_note(count), do: " · #{count} na lista de espera"

  defp roster([]) do
    """
    <p style="margin:0 0 20px;font-size:13.5px;color:#6b5544;">
      Ainda ninguém confirmado. Vale dar um empurrão na divulgação!
    </p>
    """
  end

  defp roster(participants) do
    names =
      Enum.map_join(participants, "\n", fn participant ->
        "<li style=\"margin:0 0 4px;\">#{participant_name(participant)}</li>"
      end)

    """
    <p style="margin:0 0 8px;font-size:13px;font-weight:700;color:#1a0e05;">Quem confirmou:</p>
    <ol style="margin:0 0 20px;padding-left:22px;font-size:13.5px;color:#4a3627;line-height:1.7;">
      #{names}
    </ol>
    """
  end

  defp text(name, workshop, participants, waitlist_count, manage_link, flavor) do
    """
    Oi, #{name}!

    Resumo da sua aula de #{day_phrase(flavor)}: #{workshop.title}

    Quando: #{schedule_label(workshop)}#{text_location(workshop)}
    Inscritos: #{headcount(participants, workshop)}#{waitlist_note(waitlist_count)}

    #{text_roster(participants)}
    Gerenciar inscritos: #{manage_link}
    """
  end

  defp text_location(%{location: nil}), do: ""
  defp text_location(%{location: ""}), do: ""
  defp text_location(%{location: location}), do: "\nOnde: #{location}"

  defp text_roster([]), do: "Ainda ninguém confirmado.\n"

  defp text_roster(participants) do
    names =
      participants
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {participant, index} ->
        "#{index}. #{participant_name(participant)}"
      end)

    "Quem confirmou:\n#{names}\n"
  end
end
