defmodule OGrupoDeEstudos.AgendaTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.{Brazil, Workshops}

  defp em(dias, hora) do
    Brazil.today()
    |> Date.add(dias)
    |> DateTime.new!(Time.new!(hora, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  defp programacao(dono, titulo, workshops) do
    {:ok, p} = Workshops.create_program(dono, %{title: titulo})
    for w <- workshops, do: Workshops.attach_workshop(p, dono, w.id)
    {:ok, p} = Workshops.publish_program(dono, p)
    p
  end

  defp tipos(itens), do: Enum.map(itens, & &1.kind)

  setup do
    %{dono: insert(:user, name: "Tavano Silva")}
  end

  describe "list_agenda/1 colapsando programação" do
    test "quinze workshops de um festival viram uma linha só", %{dono: dono} do
      workshops =
        for i <- 1..15 do
          insert(:workshop, organizer: dono, title: "Itaúnas #{i}", starts_at: em(20 + i, 14))
        end

      programacao(dono, "Festival de Itaúnas", workshops)

      itens = Workshops.list_agenda(period: :upcoming)

      assert tipos(itens) == [:program]
      assert [%{program: p, summary: resumo}] = itens
      assert p.title == "Festival de Itaúnas"
      assert resumo.count == 15
    end

    test "workshop solto continua aparecendo sozinho", %{dono: dono} do
      solto = insert(:workshop, organizer: dono, title: "Aulão avulso", starts_at: em(5, 19))
      agrupado = insert(:workshop, organizer: dono, starts_at: em(10, 19))
      programacao(dono, "Fim de semana", [agrupado])

      itens = Workshops.list_agenda(period: :upcoming)

      assert tipos(itens) == [:workshop, :program]
      assert hd(itens).workshop.id == solto.id
    end

    test "a mistura sai em ordem de data", %{dono: dono} do
      tarde = insert(:workshop, organizer: dono, title: "Depois", starts_at: em(30, 19))
      cedo = insert(:workshop, organizer: dono, title: "Antes", starts_at: em(2, 19))
      do_meio = insert(:workshop, organizer: dono, starts_at: em(15, 19))
      programacao(dono, "No meio", [do_meio])

      titulos =
        [period: :upcoming]
        |> Workshops.list_agenda()
        |> Enum.map(fn
          %{kind: :workshop, workshop: w} -> w.title
          %{kind: :program, program: p} -> p.title
        end)

      assert titulos == [cedo.title, "No meio", tarde.title]
      assert do_meio.id
    end

    test "programação sem workshop publicado não polui a agenda", %{dono: dono} do
      rascunho = insert(:workshop, organizer: dono, status: :draft, starts_at: em(10, 19))
      programacao(dono, "Só rascunho", [rascunho])

      assert Workshops.list_agenda(period: :upcoming) == []
    end

    test "programação em rascunho não aparece, mas o workshop dela sim", %{dono: dono} do
      w = insert(:workshop, organizer: dono, starts_at: em(10, 19))
      {:ok, p} = Workshops.create_program(dono, %{title: "Ainda montando"})
      {:ok, _} = Workshops.attach_workshop(p, dono, w.id)

      # A programacao ainda e privada, entao quem colapsaria nao existe.
      assert [%{kind: :workshop}] = Workshops.list_agenda(period: :upcoming)
    end

    test "o resumo traz o intervalo de datas do festival", %{dono: dono} do
      primeiro = insert(:workshop, organizer: dono, starts_at: em(20, 14))
      ultimo = insert(:workshop, organizer: dono, starts_at: em(25, 22))
      programacao(dono, "Festival", [primeiro, ultimo])

      assert [%{summary: resumo}] = Workshops.list_agenda(period: :upcoming)
      assert DateTime.compare(resumo.starts_at, primeiro.starts_at) == :eq
      assert DateTime.compare(resumo.ends_at, ultimo.starts_at) == :eq
    end
  end

  describe "workshop preso a programação não publicada" do
    test "programação em rascunho não engole o workshop já anunciado", %{dono: dono} do
      # Cenario real: o workshop ja circulou no WhatsApp, e o organizador
      # comeca a montar uma programacao. Ate publicar, nada pode sumir.
      w = insert(:workshop, organizer: dono, title: "Já anunciado", starts_at: em(10, 19))
      {:ok, p} = Workshops.create_program(dono, %{title: "Ainda montando"})
      {:ok, _} = Workshops.attach_workshop(p, dono, w.id)

      itens = Workshops.list_agenda(period: :upcoming)

      assert tipos(itens) == [:workshop]
      assert hd(itens).workshop.id == w.id
    end

    test "programação cancelada devolve os workshops para a agenda", %{dono: dono} do
      w = insert(:workshop, organizer: dono, title: "Continua de pé", starts_at: em(10, 19))
      p = programacao(dono, "Cancelada depois", [w])
      {:ok, _} = Workshops.cancel_program(dono, p)

      itens = Workshops.list_agenda(period: :upcoming)

      # O workshop nao foi cancelado: so a programacao foi.
      assert tipos(itens) == [:workshop]
      assert hd(itens).workshop.id == w.id
    end

    test "voltar a programação para rascunho também devolve", %{dono: dono} do
      w = insert(:workshop, organizer: dono, starts_at: em(10, 19))
      p = programacao(dono, "Publicada e despublicada", [w])
      {:ok, _} = Workshops.update_program(dono, p, %{title: "Mesma"})

      assert [%{kind: :program}] = Workshops.list_agenda(period: :upcoming)
    end
  end

  describe "list_agenda/1 com período" do
    test "a programação entra pelo período dos workshops dela", %{dono: dono} do
      do_ano = insert(:workshop, organizer: dono, starts_at: em(200, 19))
      programacao(dono, "Lá longe", [do_ano])

      assert Workshops.list_agenda(period: :week) == []
      assert [%{kind: :program}] = Workshops.list_agenda(period: :upcoming)
    end

    test "já aconteceram traz programação passada", %{dono: dono} do
      passado = insert(:workshop, organizer: dono, starts_at: em(-10, 19))
      programacao(dono, "Já foi", [passado])

      assert [%{kind: :program, program: p}] = Workshops.list_agenda(period: :past)
      assert p.title == "Já foi"
    end
  end

  describe "resumo da programação" do
    test "a contagem é do festival inteiro, não só do período filtrado", %{dono: dono} do
      desta_semana = insert(:workshop, organizer: dono, starts_at: em(2, 19))
      de_depois = for i <- 1..4, do: insert(:workshop, organizer: dono, starts_at: em(30 + i, 19))
      programacao(dono, "Festival longo", [desta_semana | de_depois])

      assert [%{summary: resumo}] = Workshops.list_agenda(period: :week)

      # O card diz "5 workshops" mesmo filtrando a semana: o numero e do
      # festival, senao ele briga com o que a pagina da programacao mostra.
      assert resumo.count == 5
    end
  end

  describe "list_agenda/1 com busca" do
    test "buscar abre a programação: acha o workshop lá dentro", %{dono: dono} do
      dentro =
        insert(:workshop, organizer: dono, title: "Pisada nordestina", starts_at: em(10, 19))

      programacao(dono, "Festival de Itaúnas", [dentro])

      itens = Workshops.list_agenda(period: :upcoming, search: "pisada")

      # Sem isso, um workshop dentro de programacao ficaria impossivel de achar.
      assert tipos(itens) == [:workshop]
      assert hd(itens).workshop.id == dentro.id
    end

    test "busca acha a programação pelo nome dela", %{dono: dono} do
      dentro = insert(:workshop, organizer: dono, title: "Qualquer coisa", starts_at: em(10, 19))
      programacao(dono, "Festival de Itaúnas", [dentro])

      itens = Workshops.list_agenda(period: :upcoming, search: "itaúnas")

      assert Enum.any?(itens, &(&1.kind == :program))
    end

    test "busca acha a programação pelo nome de quem organiza", %{dono: dono} do
      dentro = insert(:workshop, organizer: dono, starts_at: em(10, 19))
      programacao(dono, "Festival", [dentro])

      itens = Workshops.list_agenda(period: :upcoming, search: "tavano")

      assert Enum.any?(itens, &(&1.kind == :program))
    end

    test "busca não repete: se a programação casa, os workshops dela não vêm soltos", %{
      dono: dono
    } do
      manha = insert(:workshop, organizer: dono, title: "Itaúnas manhã", starts_at: em(10, 10))
      tarde = insert(:workshop, organizer: dono, title: "Itaúnas tarde", starts_at: em(10, 15))
      programacao(dono, "Festival de Itaúnas", [manha, tarde])

      itens = Workshops.list_agenda(period: :upcoming, search: "itaúnas")

      # Antes saia [workshop, program, workshop]: o pai ensanduichado entre os
      # proprios filhos, e o contador anunciando tres eventos onde ha um.
      assert tipos(itens) == [:program]
    end

    test "workshop cuja programação não casa vem solto, e diz de onde é", %{dono: dono} do
      dentro = insert(:workshop, organizer: dono, title: "Xote nordestino", starts_at: em(10, 19))
      programacao(dono, "Festival de Itaúnas", [dentro])

      assert [item] = Workshops.list_agenda(period: :upcoming, search: "xote")
      assert item.kind == :workshop
      assert item.workshop.program.title == "Festival de Itaúnas"
    end

    test "busca sem resultado devolve lista vazia", %{dono: dono} do
      w = insert(:workshop, organizer: dono, starts_at: em(10, 19))
      programacao(dono, "Festival", [w])

      assert Workshops.list_agenda(period: :upcoming, search: "xilofone") == []
    end
  end
end
