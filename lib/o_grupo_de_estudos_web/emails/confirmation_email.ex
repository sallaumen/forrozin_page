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
    <head><meta charset="UTF-8"></head>
    <body style="background:#f7f3ec;font-family:Georgia,serif;padding:40px 24px;">
      <div style="max-width:520px;margin:0 auto;">
        <p style="font-size:13px;font-weight:700;letter-spacing:2px;text-transform:uppercase;color:#1a0e05;">
          O Grupo de Estudos
        </p>
        <h1 style="font-size:22px;color:#1a0e05;margin:20px 0 8px;">
          Bem-vindo, #{name}!
        </h1>
        <p style="font-size:14px;color:#5c3a1a;line-height:1.8;">
          Sua conta foi criada. Agora voce faz parte de uma comunidade de forrozeiros
          que documenta, estuda e compartilha conhecimento sobre forro.
        </p>

        <div style="margin:24px 0;padding:16px;background:#fff;border:1px solid #e0d8c8;border-radius:8px;">
          <p style="font-size:13px;color:#1a0e05;font-weight:700;margin:0 0 8px;">O que voce pode fazer:</p>
          <ul style="font-size:13px;color:#5c3a1a;line-height:2;margin:0;padding-left:18px;">
            <li>Explorar mais de 150 passos documentados</li>
            <li>Navegar pelo mapa de conexoes entre passos</li>
            <li>Criar seu diario de treino</li>
            <li>Sugerir passos e conexoes novas</li>
            <li>Seguir outros dancarinos</li>
          </ul>
        </div>

        <p style="font-size:14px;color:#5c3a1a;line-height:1.7;">
          Confirme seu email clicando no botao abaixo para garantir acesso a
          recuperacao de senha no futuro.
        </p>

        <a href="#{link}"
           style="display:inline-block;margin:16px 0 24px;padding:12px 28px;background:#1a0e05;color:#f2ede4;text-decoration:none;font-family:Georgia,serif;font-size:14px;font-weight:700;letter-spacing:1px;border-radius:6px;">
          Confirmar email
        </a>

        <p style="font-size:12px;color:#9a7a5a;line-height:1.6;">
          Voce ja pode usar o app normalmente. A confirmacao garante acesso
          ao email de recuperacao de senha.
        </p>
        <p style="font-size:12px;color:#9a7a5a;">
          Se nao criou uma conta no Grupo de Estudos, ignore este email.
        </p>
      </div>
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
