defmodule OGrupoDeEstudos.Repo.Migrations.InvitesViramPedidos do
  use Ecto.Migration

  # Workshop privado deixa de ser invisivel e passa a ser "entrada por
  # aprovacao": aparece na agenda como qualquer outro, e quem quer entrar pede.
  # A autoria da linha inverte (antes quem organiza convidava; agora a pessoa
  # pede) e por isso a tabela muda de nome junto: continuar chamando de
  # "convite" faria o codigo mentir.
  #
  # Sem backfill: producao nao tem workshop nenhum, entao nao ha linha para
  # migrar. O default 'approved' existe so para nao deixar linha de dev orfa
  # de status, ja que convite antigo equivalia a acesso concedido.
  def change do
    rename table(:workshop_invites), to: table(:workshop_join_requests)
    rename table(:workshop_join_requests), :invited_by_id, to: :reviewed_by_id

    alter table(:workshop_join_requests) do
      add :status, :string, null: false, default: "approved"
      add :reviewed_at, :utc_datetime
    end
  end
end
