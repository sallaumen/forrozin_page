defmodule Forrozin.Repo.Migrations.AddVideoUrlToSequences do
  use Ecto.Migration

  def change do
    alter table(:sequences) do
      add :video_url, :string
      add :description, :text
    end
  end
end
