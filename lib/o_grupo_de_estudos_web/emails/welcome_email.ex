defmodule OGrupoDeEstudosWeb.Emails.WelcomeEmail do
  @moduledoc """
  Welcome email sent at registration, in five rotating variations.

  Password signups get the confirmation call to action (confirmation only
  gates password recovery, and the email says so). Google signups arrive
  with the email already verified, so the confirmation block gives way to
  a note about it.
  """

  alias Swoosh.Email

  use OGrupoDeEstudosWeb, :verified_routes

  @sender {"O Grupo de Estudos", "noreply@ogrupodeestudos.com.br"}
  @variation_count 5

  @doc "Builds the welcome email with a randomly picked variation."
  def new(user), do: new(user, Enum.random(0..(@variation_count - 1)))

  @doc "Builds the welcome email with a specific variation (tests, previews)."
  def new(user, variation_index) do
    first_name = user.name |> String.split() |> hd()
    variation = variation(variation_index, first_name)

    Email.new()
    |> Email.to({user.name || user.username, user.email})
    |> Email.from(@sender)
    |> Email.subject(variation.subject)
    |> Email.html_body(html(variation, confirmation_block(user)))
    |> Email.text_body(text(variation, confirmation_text(user)))
  end

  defp variation(0, name) do
    %{
      subject: "Salve, #{name}! Bem-vindo ao Grupo de Estudos",
      title: "Salve, #{name}!",
      intro:
        "Sua conta tá criada e pronta pra usar. Agora você faz parte de uma comunidade " <>
          "de forrozeiros que documenta e compartilha o que sabe sobre a dança.",
      closing: "Bom treino, e até a pista."
    }
  end

  defp variation(1, name) do
    %{
      subject: "Chegou gente nova no forró: você",
      title: "Oi, #{name}!",
      intro:
        "Conta criada, porteira aberta. Aqui a gente cataloga passo, conexão e sequência " <>
          "de forró como quem cuida de acervo: com carinho e sem frescura.",
      closing: "Qualquer dúvida, chama. Bom treino!"
    }
  end

  defp variation(2, name) do
    %{
      subject: "#{name}, sua conta no Grupo de Estudos tá no ar",
      title: "Tudo certo, #{name}!",
      intro:
        "Conta pronta. Pode entrar, fuçar o acervo, montar sequência e anotar treino " <>
          "no diário. O resto a pisada ensina.",
      closing: "Até a próxima dança."
    }
  end

  defp variation(3, name) do
    %{
      subject: "Bora estudar forró, #{name}?",
      title: "E aí, #{name}!",
      intro:
        "Sua conta tá pronta. Comece pelo acervo, que tem mais de cem passos documentados, " <>
          "e vá seguindo as conexões: um passo puxa o outro, igual numa boa noite de forró.",
      closing: "Bom estudo e boa pista!"
    }
  end

  defp variation(4, name) do
    %{
      subject: "Pisada registrada, #{name}",
      title: "Salve, salve, #{name}!",
      intro:
        "Agora é oficial: você faz parte do Grupo de Estudos. Tem acervo, mapa de conexões, " <>
          "diário de treino e uma comunidade inteira pra trocar figurinha de pisada.",
      closing: "Te vejo no salão."
    }
  end

  # Password signups confirm the email to guarantee recovery; Google signups
  # arrive verified, so the block turns into a note.
  defp confirmation_block(%{confirmation_token: token}) when is_binary(token) do
    link = url(~p"/confirm/#{token}")

    """
    <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;">
      <tr><td align="center" style="padding:20px;background:#faf8f4;border:1px solid #e8e0d4;border-radius:10px;">
        <p style="margin:0 0 12px;font-size:13px;color:#5c3a1a;">
          Só falta confirmar o email pra garantir recuperação de senha:
        </p>
        <a href="#{link}"
           style="display:inline-block;padding:14px 44px;background:#b47828;color:#ffffff;text-decoration:none;font-family:Georgia,serif;font-size:16px;font-weight:700;letter-spacing:0.5px;border-radius:8px;">
          Confirmar email
        </a>
      </td></tr>
    </table>
    """
  end

  defp confirmation_block(_google_user) do
    """
    <p style="margin:0 0 24px;padding:14px 16px;background:#faf8f4;border:1px solid #e8e0d4;border-radius:10px;font-size:13px;color:#5c3a1a;line-height:1.6;">
      Você entrou com o Google, então seu email já tá confirmado e não tem senha pra decorar.
      Se um dia quiser uma senha própria, é só usar o "esqueci minha senha".
    </p>
    """
  end

  defp confirmation_text(%{confirmation_token: token}) when is_binary(token) do
    """
    Confirme seu email para garantir recuperação de senha:
    #{url(~p"/confirm/#{token}")}

    Você já pode usar o app normalmente. A confirmação só é necessária
    pra recuperação de senha.
    """
  end

  defp confirmation_text(_google_user) do
    """
    Você entrou com o Google, então seu email já tá confirmado e não tem
    senha pra decorar. Se um dia quiser uma senha própria, é só usar o
    "esqueci minha senha" na tela de login.
    """
  end

  defp html(variation, confirmation_html) do
    """
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
    <body style="margin:0;padding:0;background:#f0ece4;font-family:Georgia,'Times New Roman',serif;">
      <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0ece4;padding:32px 16px;">
        <tr><td align="center">
          <table width="520" cellpadding="0" cellspacing="0" style="max-width:520px;width:100%;">
            <tr><td style="background:#1a0e05;padding:20px 28px;border-radius:12px 12px 0 0;" align="center">
              <img src="https://ogrupodeestudos.com.br/icons/icon-192.png" width="40" height="40" alt="OGE" style="border-radius:10px;margin-bottom:8px;display:block;" />
              <p style="margin:0;font-size:11px;font-weight:700;letter-spacing:3px;text-transform:uppercase;color:#d4a574;">
                O Grupo de Estudos
              </p>
            </td></tr>

            <tr><td style="background:#ffffff;padding:32px 28px 24px;border-left:1px solid #e8e0d4;border-right:1px solid #e8e0d4;">
              <h1 style="margin:0 0 8px;font-size:22px;color:#1a0e05;font-weight:700;">
                #{variation.title}
              </h1>
              <p style="margin:0 0 20px;font-size:14px;color:#5c3a1a;line-height:1.8;">
                #{variation.intro}
              </p>

              #{confirmation_html}

              <p style="margin:0 0 8px;font-size:13px;font-weight:700;color:#1a0e05;">O que te espera:</p>
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:8px;">
                <tr><td style="padding:8px 0;font-size:13px;color:#5c3a1a;line-height:1.6;">
                  <span style="color:#b47828;font-weight:700;">Acervo</span>: mais de cem passos por categoria, com conexões e vídeos
                </td></tr>
                <tr><td style="padding:8px 0;font-size:13px;color:#5c3a1a;line-height:1.6;border-top:1px solid #f0ece4;">
                  <span style="color:#b47828;font-weight:700;">Mapa</span>: como os passos se conectam, visualmente
                </td></tr>
                <tr><td style="padding:8px 0;font-size:13px;color:#5c3a1a;line-height:1.6;border-top:1px solid #f0ece4;">
                  <span style="color:#b47828;font-weight:700;">Diário</span>: anote treinos, acompanhe evolução
                </td></tr>
                <tr><td style="padding:8px 0;font-size:13px;color:#5c3a1a;line-height:1.6;border-top:1px solid #f0ece4;">
                  <span style="color:#b47828;font-weight:700;">Comunidade</span>: siga pessoas, crie sequências, contribua
                </td></tr>
              </table>

              <p style="margin:16px 0 0;font-size:13px;color:#5c3a1a;">#{variation.closing}</p>
            </td></tr>

            <tr><td style="background:#f0ece4;padding:16px 28px;border-radius:0 0 12px 12px;border:1px solid #e8e0d4;border-top:0;">
              <p style="margin:0;font-size:11px;color:#c0b0a0;">
                Não criou conta? Ignora esse email.
              </p>
            </td></tr>
          </table>
        </td></tr>
      </table>
    </body>
    </html>
    """
  end

  defp text(variation, confirmation_text) do
    """
    O Grupo de Estudos

    #{variation.title}

    #{variation.intro}

    O que te espera:
    - Acervo: mais de cem passos documentados, com conexões e vídeos
    - Mapa: como os passos se conectam, visualmente
    - Diário: anote treinos, acompanhe evolução
    - Comunidade: siga pessoas, crie sequências, contribua

    #{confirmation_text}
    #{variation.closing}

    Se não criou uma conta no Grupo de Estudos, ignore este email.
    """
  end
end
