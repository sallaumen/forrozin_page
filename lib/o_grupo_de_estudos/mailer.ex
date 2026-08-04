defmodule OGrupoDeEstudos.Mailer do
  @moduledoc """
  Application mailer.

  In dev, when `:filter_test_emails` is enabled in the config, emails whose
  recipient ends in `@teste.com` are diverted to the local mailbox (visible at
  /dev/mailbox) instead of actually being sent. Every other email goes through
  the configured adapter.
  """

  use Swoosh.Mailer, otp_app: :o_grupo_de_estudos

  alias Swoosh.Adapters.Local

  @dominio_filtrado "@teste.com"

  def deliver(email, config \\ []) do
    if filter_local?(email) do
      Local.deliver(email, [])
    else
      super(email, config)
    end
  end

  defp filter_local?(email) do
    Application.get_env(:o_grupo_de_estudos, :filter_test_emails, false) and
      dominio_teste?(email)
  end

  defp dominio_teste?(email) do
    (email.to ++ email.cc ++ email.bcc)
    |> Enum.any?(fn
      {_name, addr} -> String.ends_with?(addr, @dominio_filtrado)
      addr -> String.ends_with?(addr, @dominio_filtrado)
    end)
  end
end
