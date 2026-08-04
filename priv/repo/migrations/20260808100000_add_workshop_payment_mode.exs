defmodule OGrupoDeEstudos.Repo.Migrations.AddWorkshopPaymentMode do
  use Ecto.Migration

  # "Como as pessoas pagam" era campo de texto livre, e texto livre o sistema
  # nao consegue usar: nao da para mostrar o jeito certo de pagar, nem oferecer
  # o atalho de mandar o comprovante. Agora o QUANDO e uma escolha entre duas
  # opcoes, e para quem paga na inscricao ha um telefone de destino.
  #
  # `payment_info` continua, com outro papel: deixa de carregar o quando e passa
  # a carregar so a chave Pix ou uma instrucao extra.
  #
  # Sem backfill: producao nao tem workshop nenhum. As linhas de dev ficam com
  # o modo nulo, que a tela ja trata como "combinado com quem organiza".
  def change do
    alter table(:workshops) do
      add :payment_mode, :string
      add :payment_phone, :string
    end
  end
end
