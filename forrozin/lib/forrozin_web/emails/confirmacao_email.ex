defmodule ForrozinWeb.Emails.ConfirmacaoEmail do
  @moduledoc "Email de confirmação de conta enviado após o cadastro."

  alias Swoosh.Email

  use ForrozinWeb, :verified_routes

  @remetente {"Forrózin", "noreply@forrozin.com.br"}

  @doc "Cria o email de confirmação para o usuário."
  def novo(user) do
    link = url(~p"/confirmar/#{user.confirmation_token}")

    Email.new()
    |> Email.to({user.nome_usuario, user.email})
    |> Email.from(@remetente)
    |> Email.subject("Confirme seu email — Forrózin")
    |> Email.html_body(html(user.nome_usuario, link))
    |> Email.text_body(texto(user.nome_usuario, link))
  end

  defp html(nome, link) do
    """
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head><meta charset="UTF-8"></head>
    <body style="background:#f7f3ec;font-family:Georgia,serif;padding:40px 24px;">
      <div style="max-width:520px;margin:0 auto;">
        <p style="font-size:13px;font-weight:700;letter-spacing:2px;text-transform:uppercase;color:#1a0e05;">
          Forrózin
        </p>
        <h1 style="font-size:20px;color:#1a0e05;margin:20px 0 8px;">
          Confirme seu email
        </h1>
        <p style="font-size:14px;color:#5c3a1a;line-height:1.7;">
          Olá, #{nome}! Clique no botão abaixo para confirmar seu email e acessar o acervo.
        </p>
        <a href="#{link}"
           style="display:inline-block;margin:24px 0;padding:12px 28px;background:#1a0e05;color:#f2ede4;text-decoration:none;font-family:Georgia,serif;font-size:14px;font-weight:700;letter-spacing:1px;border-radius:4px;">
          Confirmar email
        </a>
        <p style="font-size:12px;color:#9a7a5a;">
          Se não criou uma conta no Forrózin, ignore este email.
        </p>
      </div>
    </body>
    </html>
    """
  end

  defp texto(nome, link) do
    """
    Forrózin — Confirme seu email

    Olá, #{nome}!

    Confirme seu email acessando o link abaixo:
    #{link}

    Se não criou uma conta no Forrózin, ignore este email.
    """
  end
end
