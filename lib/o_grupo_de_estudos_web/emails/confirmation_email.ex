defmodule OGrupoDeEstudosWeb.Emails.ConfirmationEmail do
  @moduledoc """
  Combined welcome + confirmation email sent at registration.

  The user can use the app immediately — confirmation only gates
  password-recovery. The email makes this clear.
  """

  alias Swoosh.Email

  use OGrupoDeEstudosWeb, :verified_routes

  @sender {"O Grupo de Estudos", "noreply@ogrupodeestudos.com.br"}

  @doc "Builds the welcome + confirmation email for the given user."
  def new(user) do
    link = url(~p"/confirm/#{user.confirmation_token}")
    display_name = user.name || user.username

    Email.new()
    |> Email.to({display_name, user.email})
    |> Email.from(@sender)
    |> Email.subject("Bem-vindo ao Grupo de Estudos! Confirme seu email")
    |> Email.html_body(html(display_name, link))
    |> Email.text_body(text(display_name, link))
  end

  defp html(name, link) do
    """
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
    <body style="margin:0;padding:0;background:#f0ece4;font-family:Georgia,'Times New Roman',serif;">
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0ece4;padding:32px 16px;">
        <tr><td align="center">
          <table width="520" cellpadding="0" cellspacing="0" style="max-width:520px;width:100%;">
            <!-- Header -->
            <tr><td style="background:#1a0e05;padding:20px 28px;border-radius:12px 12px 0 0;" align="center">
              <img src="https://ogrupodeestudos.com.br/icons/icon-192.png" width="40" height="40" alt="OGE" style="border-radius:10px;margin-bottom:8px;display:block;" />
              <p style="margin:0;font-size:11px;font-weight:700;letter-spacing:3px;text-transform:uppercase;color:#d4a574;">
                O Grupo de Estudos
              </p>
            </td></tr>

            <!-- Body -->
            <tr><td style="background:#ffffff;padding:32px 28px 24px;border-left:1px solid #e8e0d4;border-right:1px solid #e8e0d4;">
              <h1 style="margin:0 0 6px;font-size:24px;color:#1a0e05;font-weight:700;">
                Bem-vindo, #{name}!
              </h1>
              <p style="margin:0 0 20px;font-size:14px;color:#7a5c3a;line-height:1.7;">
                Sua conta foi criada. Agora voce faz parte de uma comunidade que documenta, estuda e compartilha conhecimento sobre forro.
              </p>

              <!-- Features grid -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;">
                <tr>
                  <td style="padding:10px 12px;background:#faf8f4;border:1px solid #e8e0d4;border-radius:8px 0 0 8px;width:50%;vertical-align:top;">
                    <p style="margin:0 0 2px;font-size:18px;font-weight:700;color:#b47828;">150+</p>
                    <p style="margin:0;font-size:11px;color:#7a5c3a;">passos documentados</p>
                  </td>
                  <td style="padding:10px 12px;background:#faf8f4;border:1px solid #e8e0d4;border-left:0;border-radius:0 8px 8px 0;width:50%;vertical-align:top;">
                    <p style="margin:0 0 2px;font-size:18px;font-weight:700;color:#b47828;">100%</p>
                    <p style="margin:0;font-size:11px;color:#7a5c3a;">gratuito, pra sempre</p>
                  </td>
                </tr>
              </table>

              <p style="margin:0 0 4px;font-size:12px;font-weight:700;color:#1a0e05;">O que voce encontra:</p>
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;">
                <tr><td style="padding:6px 0;font-size:13px;color:#5c3a1a;line-height:1.5;">
                  <span style="color:#b47828;font-weight:700;">Acervo</span> — passos organizados por categoria com conexoes e videos
                </td></tr>
                <tr><td style="padding:6px 0;font-size:13px;color:#5c3a1a;line-height:1.5;border-top:1px solid #f0ece4;">
                  <span style="color:#b47828;font-weight:700;">Mapa</span> — grafo visual mostrando como os passos se conectam
                </td></tr>
                <tr><td style="padding:6px 0;font-size:13px;color:#5c3a1a;line-height:1.5;border-top:1px solid #f0ece4;">
                  <span style="color:#b47828;font-weight:700;">Diario</span> — registre seus treinos e acompanhe sua evolucao
                </td></tr>
                <tr><td style="padding:6px 0;font-size:13px;color:#5c3a1a;line-height:1.5;border-top:1px solid #f0ece4;">
                  <span style="color:#b47828;font-weight:700;">Comunidade</span> — siga dancarinos, crie sequencias, contribua
                </td></tr>
              </table>
            </td></tr>

            <!-- CTA -->
            <tr><td style="background:#faf8f4;padding:24px 28px;text-align:center;border-left:1px solid #e8e0d4;border-right:1px solid #e8e0d4;">
              <p style="margin:0 0 14px;font-size:13px;color:#5c3a1a;">
                Confirme seu email para garantir acesso a recuperacao de senha:
              </p>
              <a href="#{link}"
                 style="display:inline-block;padding:14px 40px;background:#b47828;color:#ffffff;text-decoration:none;font-family:Georgia,serif;font-size:15px;font-weight:700;letter-spacing:0.5px;border-radius:8px;">
                Confirmar email
              </a>
            </td></tr>

            <!-- Footer -->
            <tr><td style="background:#f0ece4;padding:20px 28px;border-radius:0 0 12px 12px;border:1px solid #e8e0d4;border-top:0;">
              <p style="margin:0 0 4px;font-size:11px;color:#9a7a5a;line-height:1.5;">
                Voce ja pode usar o app normalmente. A confirmacao so garante recuperacao de senha.
              </p>
              <p style="margin:0;font-size:11px;color:#c0b0a0;">
                Se nao criou uma conta, ignore este email.
              </p>
            </td></tr>
          </table>
        </td></tr>
      </table>
    </body>
    </html>
    """
  end

  defp text(name, link) do
    """
    O Grupo de Estudos | Bem-vindo!

    Ola, #{name}!

    Sua conta foi criada. Agora voce faz parte de uma comunidade
    de forrozeiros que documenta, estuda e compartilha conhecimento.

    O que voce pode fazer:
    - Explorar mais de 150 passos documentados
    - Navegar pelo mapa de conexoes entre passos
    - Criar seu diario de treino
    - Sugerir passos e conexoes novas
    - Seguir outros dancarinos

    Confirme seu email para garantir recuperacao de senha:
    #{link}

    Voce ja pode usar o app normalmente. A confirmacao garante
    acesso ao email de recuperacao de senha.

    Se nao criou uma conta no Grupo de Estudos, ignore este email.
    """
  end
end
