defmodule OGrupoDeEstudos.Engagement.Notifications.NotificationQueryTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Engagement.Notifications.{Grouper, Notification, NotificationQuery}
  alias OGrupoDeEstudos.Repo

  # `insert_all` porque é assim que o Dispatcher grava: sem changeset.
  defp notificar(user, actor, group_key, opts) do
    now = Keyword.get(opts, :at, NaiveDateTime.utc_now()) |> NaiveDateTime.truncate(:second)

    Repo.insert_all(Notification, [
      %{
        id: Ecto.UUID.generate(),
        user_id: user.id,
        actor_id: actor.id,
        action: Keyword.get(opts, :action, :followed_user),
        group_key: group_key,
        target_type: "profile",
        target_id: actor.id,
        parent_type: "profile",
        parent_id: actor.id,
        read_at: Keyword.get(opts, :read_at),
        inserted_at: now
      }
    ])
  end

  defp minutos_atras(n), do: NaiveDateTime.add(NaiveDateTime.utc_now(), -n * 60, :second)

  describe "list_for_user/2 com limite" do
    test "o limite conta assuntos, não linhas", %{} do
      dono = insert(:user)

      # Uma avalanche num assunto só: 30 pessoas no mesmo group_key.
      for i <- 1..30 do
        notificar(dono, insert(:user), "workshop_enrolled:abc", at: minutos_atras(i))
      end

      # E uma novidade de outro assunto, mais antiga que a avalanche inteira.
      antiga = insert(:user)
      notificar(dono, antiga, "follow:xyz", at: minutos_atras(100))

      notificacoes = NotificationQuery.list_for_user(dono.id, limit: 8)
      grupos = Grouper.group(notificacoes)

      # Antes, as 8 linhas mais recentes eram todas da avalanche e o follow
      # sumia da prévia. Agora o corte é por assunto.
      assert length(grupos) == 2
      assert Enum.find(grupos, &(&1.parent_id == antiga.id))
    end

    test "a contagem de atores do grupo sobrevive ao corte" do
      dono = insert(:user)

      for i <- 1..30 do
        notificar(dono, insert(:user), "workshop_enrolled:abc", at: minutos_atras(i))
      end

      [grupo] =
        dono.id
        |> NotificationQuery.list_for_user(limit: 8)
        |> Grouper.group()

      # "Fulano e mais 29" só sai se todas as linhas do assunto vierem juntas.
      assert grupo.count == 30
    end

    test "quando só cabe um assunto, o não lido ganha do lido mais recente" do
      dono = insert(:user)
      lido = insert(:user)
      nao_lido = insert(:user)
      agora = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      notificar(dono, lido, "follow:lido",
        at: agora,
        read_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )

      notificar(dono, nao_lido, "follow:novo", at: minutos_atras(30))

      # O lido é mais recente, mas quem tem novidade entra na frente no corte.
      assert [notificacao] = NotificationQuery.list_for_user(dono.id, limit: 1)
      assert notificacao.actor_id == nao_lido.id
    end

    test "offset pagina por assunto" do
      dono = insert(:user)

      for i <- 1..5 do
        notificar(dono, insert(:user), "follow:#{i}", at: minutos_atras(i))
      end

      primeira_pagina = dono.id |> NotificationQuery.list_for_user(limit: 2) |> Grouper.group()

      segunda_pagina =
        dono.id |> NotificationQuery.list_for_user(limit: 2, offset: 2) |> Grouper.group()

      assert length(primeira_pagina) == 2
      assert length(segunda_pagina) == 2

      ids_primeira = MapSet.new(primeira_pagina, & &1.id)
      ids_segunda = MapSet.new(segunda_pagina, & &1.id)
      assert MapSet.disjoint?(ids_primeira, ids_segunda)
    end

    test "sem notificação devolve lista vazia" do
      assert NotificationQuery.list_for_user(insert(:user).id, limit: 8) == []
    end
  end
end
