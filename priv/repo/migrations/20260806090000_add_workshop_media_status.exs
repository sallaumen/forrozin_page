defmodule OGrupoDeEstudos.Repo.Migrations.AddWorkshopMediaStatus do
  use Ecto.Migration

  # A video enters the gallery before it is transcoded: the upload answers right
  # away and ffmpeg runs afterwards, in a queue with concurrency 1. The status tells
  # the screen whether it can play yet.
  #
  # Default 'ready' because a photo is born ready, and because the rows that already
  # exist went through no transcode: no backfill here.
  def change do
    # No index: nobody queries by status. The gallery reads by workshop_id, and what
    # finds an interrupted transcode is Oban.Plugins.Lifeline, which looks at its own
    # jobs table.
    alter table(:workshop_media) do
      add :status, :string, null: false, default: "ready"
    end
  end
end
