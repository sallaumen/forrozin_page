defmodule OGrupoDeEstudosWeb.Emails.WelcomeEmail do
  @moduledoc "Welcome email sent after the user confirms their email."

  alias Swoosh.Email

  @sender {"O Grupo de Estudos", "noreply@o_grupo_de_estudos.com.br"}

  @doc "Builds the welcome email for the given user."
  def new(user) do
    Email.new()
    |> Email.to({user.name || user.username, user.email})
    |> Email.from(@sender)
    |> Email.subject("Bem-vindo ao Grupo de Estudos!")
    |> Email.html_body(html(user.name || user.username))
    |> Email.text_body(text(user.name || user.username))
  end

  defp html(name) do
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
          Sua conta foi confirmada. Agora voce faz parte de uma comunidade de forrozeiros
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

        <a href="https://ogrupodeestudos.com.br/collection"
           style="display:inline-block;margin:8px 0 24px;padding:12px 28px;background:#1a0e05;color:#f2ede4;text-decoration:none;font-family:Georgia,serif;font-size:14px;font-weight:700;letter-spacing:1px;border-radius:6px;">
          Explorar o acervo
        </a>

        <p style="font-size:12px;color:#9a7a5a;line-height:1.6;">
          Esse projeto e 100% gratuito e construido pela comunidade.
          Se tiver duvidas ou sugestoes, e so mandar.
        </p>
      </div>
    </body>
    </html>
    """
  end

  defp text(name) do
    """
    O Grupo de Estudos | Bem-vindo!

    Ola, #{name}!

    Sua conta foi confirmada. Agora voce faz parte de uma comunidade
    de forrozeiros que documenta, estuda e compartilha conhecimento.

    O que voce pode fazer:
    - Explorar mais de 150 passos documentados
    - Navegar pelo mapa de conexoes entre passos
    - Criar seu diario de treino
    - Sugerir passos e conexoes novas
    - Seguir outros dancarinos

    Acesse: https://ogrupodeestudos.com.br/collection

    Esse projeto e 100% gratuito e construido pela comunidade.
    """
  end
end
