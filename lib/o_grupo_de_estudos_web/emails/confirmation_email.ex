defmodule OGrupoDeEstudosWeb.Emails.ConfirmationEmail do
  @moduledoc "Confirmation email sent to the user after registration."

  alias Swoosh.Email

  use OGrupoDeEstudosWeb, :verified_routes

  @sender {"O Grupo de Estudos", "noreply@o_grupo_de_estudos.com.br"}

  @doc "Builds the confirmation email for the given user."
  def new(user) do
    link = url(~p"/confirm/#{user.confirmation_token}")

    Email.new()
    |> Email.to({user.username, user.email})
    |> Email.from(@sender)
    |> Email.subject("Confirme seu email | O Grupo de Estudos")
    |> Email.html_body(html(user.username, link))
    |> Email.text_body(text(user.username, link))
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
        <h1 style="font-size:20px;color:#1a0e05;margin:20px 0 8px;">
          Confirme seu email
        </h1>
        <p style="font-size:14px;color:#5c3a1a;line-height:1.7;">
          Olá, #{name}! Clique no botão abaixo para confirmar seu email e acessar o acervo.
        </p>
        <a href="#{link}"
           style="display:inline-block;margin:24px 0;padding:12px 28px;background:#1a0e05;color:#f2ede4;text-decoration:none;font-family:Georgia,serif;font-size:14px;font-weight:700;letter-spacing:1px;border-radius:4px;">
          Confirmar email
        </a>
        <p style="font-size:12px;color:#9a7a5a;">
          Se não criou uma conta no Grupo de Estudos, ignore este email.
        </p>
      </div>
    </body>
    </html>
    """
  end

  defp text(name, link) do
    """
    O Grupo de Estudos | Confirme seu email

    Olá, #{name}!

    Confirme seu email acessando o link abaixo:
    #{link}

    Se não criou uma conta no Grupo de Estudos, ignore este email.
    """
  end
end
