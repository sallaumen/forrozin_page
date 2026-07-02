defmodule OGrupoDeEstudos.Repo.Migrations.NormalizeNotificationActions do
  use Ecto.Migration

  # Migration corretiva de dados (pequena, indexada — não é backfill):
  # Notification.action vira Ecto.Enum e uma linha antiga com action fora
  # do conjunto conhecido quebraria o load. O release_command do Fly roda
  # migrations ANTES do rollout, então o dado fica limpo antes do código
  # novo servir. Notificações com action desconhecido já eram inroteáveis
  # na UI; remover é a correção.

  @known_actions ~w(replied_comment liked_comment liked_step liked_sequence
                    followed_user study_request study_accepted study_nudge
                    shared_note_updated suggestion_created suggestion_approved
                    suggestion_rejected)

  def up do
    placeholders = @known_actions |> Enum.map(&"'#{&1}'") |> Enum.join(", ")

    %{num_rows: removed} =
      repo().query!("DELETE FROM notifications WHERE action NOT IN (#{placeholders})")

    IO.puts("NormalizeNotificationActions: #{removed} notificações com action legado removidas")
  end

  def down do
    # Sem down: a remoção de linhas inroteáveis não é reversível nem precisa ser.
    :ok
  end
end
