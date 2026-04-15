defmodule OGrupoDeEstudos.Mailer do
  @moduledoc """
  Mailer da aplicação.

  Em dev, se `:filtrar_emails_teste` estiver habilitado no config, emails cujo
  destinatário termine em `@teste.com` são desviados para o mailbox local
  (visível em /dev/mailbox) em vez de serem enviados de verdade.
  Todos os outros emails seguem pelo adaptador configurado.
  """

  use Swoosh.Mailer, otp_app: :o_grupo_de_estudos

  alias Swoosh.Adapters.Local

  @dominio_filtrado "@teste.com"

  def deliver(email, config \\ []) do
    if filtrar_local?(email) do
      Local.deliver(email, [])
    else
      super(email, config)
    end
  end

  defp filtrar_local?(email) do
    Application.get_env(:o_grupo_de_estudos, :filtrar_emails_teste, false) and dominio_teste?(email)
  end

  defp dominio_teste?(email) do
    (email.to ++ email.cc ++ email.bcc)
    |> Enum.any?(fn
      {_name, addr} -> String.ends_with?(addr, @dominio_filtrado)
      addr -> String.ends_with?(addr, @dominio_filtrado)
    end)
  end
end
