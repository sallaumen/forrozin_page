defmodule OGrupoDeEstudos.Repo.Migrations.AddWorkshopMediaStatus do
  use Ecto.Migration

  # Video entra na galeria antes de estar transcodificado: o upload responde na
  # hora e o ffmpeg roda depois, numa fila com concurrency 1. O status diz para
  # a tela se ja da para tocar.
  #
  # Default 'ready' porque foto nasce pronta, e porque a linha que ja existe
  # nao passou por transcode nenhum: nada de backfill aqui.
  def change do
    # Sem indice: ninguem consulta por status. A galeria le por workshop_id, e
    # quem reencontra transcode interrompido e o Oban.Plugins.Lifeline, que
    # olha a propria tabela de jobs.
    alter table(:workshop_media) do
      add :status, :string, null: false, default: "ready"
    end
  end
end
