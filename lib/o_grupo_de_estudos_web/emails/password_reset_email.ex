defmodule OGrupoDeEstudosWeb.Emails.PasswordResetEmail do
  @moduledoc """
  Password reset email with progressive humor based on how many
  times the user has reset their password.
  """

  import Swoosh.Email

  @from {"O Grupo de Estudos", "noreply@ogrupodeestudos.com.br"}
  @subject "Recuperação de senha"

  def new(user, reset_url, reset_count) do
    body_text = message_for_count(reset_count)

    new()
    |> to({user.name || user.username, user.email})
    |> from(@from)
    |> subject(@subject)
    |> html_body(html_template(user, reset_url, body_text))
    |> text_body(text_template(user, reset_url, body_text))
  end

  defp message_for_count(count) when count <= 1 do
    "Oi! Segue o link pra você criar uma senha nova. Acontece com todo mundo, relaxa."
  end

  defp message_for_count(2) do
    "Tudo bem, a gente esquece mesmo. Toma o link aí, sem julgamentos rsrs"
  end

  defp message_for_count(3) do
    "Terceira vez já! Tô começando a achar que você gosta de receber meus emails suahsuhauhs"
  end

  defp message_for_count(4) do
    "Olha, vou começar a cobrar por email. Brincadeira. Toma o link kkkkkkk"
  end

  defp message_for_count(_count) do
    "Quer saber, faz o que quiser! Toma o link. Usa, esquece, pede de novo, tanto faz. Vamos gastar o servidor do Tavano mesmo KKKKKKKKKKYING"
  end

  defp html_template(user, reset_url, body_text) do
    name = user.name || user.username

    """
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head><meta charset="utf-8"/></head>
    <body style="margin:0;padding:0;background:#1a0e05;font-family:Georgia,'Iowan Old Style',serif;">
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#1a0e05;padding:40px 20px;">
        <tr><td align="center">
          <table width="560" cellpadding="0" cellspacing="0" style="background:#faf8f4;border-radius:12px;overflow:hidden;">
            <!-- Header -->
            <tr><td style="background:#1a0e05;padding:24px 32px;text-align:center;">
              <span style="font-size:13px;font-weight:700;letter-spacing:3px;color:#d4a054;text-transform:uppercase;">
                O Grupo de Estudos
              </span>
            </td></tr>
            <!-- Body -->
            <tr><td style="padding:32px 32px 16px;">
              <p style="font-size:18px;font-weight:700;color:#1a0e05;margin:0 0 16px;">
                E aí, #{name}!
              </p>
              <p style="font-size:15px;color:#5c4a3a;line-height:1.7;margin:0 0 24px;">
                #{body_text}
              </p>
              <table cellpadding="0" cellspacing="0" style="margin:0 auto;">
                <tr><td style="background:#e67e22;border-radius:8px;">
                  <a href="#{reset_url}" style="display:inline-block;padding:14px 32px;color:#ffffff;font-size:14px;font-weight:700;text-decoration:none;letter-spacing:0.5px;">
                    Criar nova senha
                  </a>
                </td></tr>
              </table>
            </td></tr>
            <!-- Footer -->
            <tr><td style="padding:16px 32px 32px;">
              <p style="font-size:12px;color:#9a8a78;line-height:1.6;margin:16px 0 0;text-align:center;">
                Este link expira em 30 minutos.<br/>
                Se você não pediu isso, pode ignorar este email.
              </p>
            </td></tr>
          </table>
        </td></tr>
      </table>
    </body>
    </html>
    """
  end

  defp text_template(user, reset_url, body_text) do
    name = user.name || user.username

    """
    E aí, #{name}!

    #{body_text}

    Clica aqui pra criar uma senha nova:
    #{reset_url}

    Este link expira em 30 minutos.
    Se você não pediu isso, pode ignorar.
    """
  end
end
