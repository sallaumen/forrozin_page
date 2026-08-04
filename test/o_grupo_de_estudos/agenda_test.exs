defmodule OGrupoDeEstudos.AgendaTest do
  use OGrupoDeEstudos.DataCase, async: true

  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.{Brazil, Workshops}

  defp at_day(days, hour) do
    Brazil.today()
    |> Date.add(days)
    |> DateTime.new!(Time.new!(hour, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  defp program(owner, title, workshops) do
    {:ok, p} = Workshops.create_program(owner, %{title: title})
    for w <- workshops, do: Workshops.attach_workshop(p, owner, w.id)
    {:ok, p} = Workshops.publish_program(owner, p)
    p
  end

  defp tipos(itens), do: Enum.map(itens, & &1.kind)

  setup do
    %{owner: insert(:user, name: "Tavano Silva")}
  end

  describe "list_agenda/1 collapsing programs" do
    test "collapses fifteen workshops of a festival into a single entry", %{owner: owner} do
      workshops =
        for i <- 1..15 do
          insert(:workshop,
            organizer: owner,
            title: "Itaúnas #{i}",
            starts_at: at_day(20 + i, 14)
          )
        end

      program(owner, "Festival de Itaúnas", workshops)

      itens = Workshops.list_agenda(period: :upcoming)

      assert tipos(itens) == [:program]
      assert [%{program: p, summary: summary}] = itens
      assert p.title == "Festival de Itaúnas"
      assert summary.count == 15
    end

    test "workshop solto continua aparecendo sozinho", %{owner: owner} do
      solto = insert(:workshop, organizer: owner, title: "Aulão avulso", starts_at: at_day(5, 19))
      grouped = insert(:workshop, organizer: owner, starts_at: at_day(10, 19))
      program(owner, "Fim de semana", [grouped])

      itens = Workshops.list_agenda(period: :upcoming)

      assert tipos(itens) == [:workshop, :program]
      assert hd(itens).workshop.id == solto.id
    end

    test "returns programs and loose workshops ordered by date", %{owner: owner} do
      tarde = insert(:workshop, organizer: owner, title: "Depois", starts_at: at_day(30, 19))
      cedo = insert(:workshop, organizer: owner, title: "Antes", starts_at: at_day(2, 19))
      do_meio = insert(:workshop, organizer: owner, starts_at: at_day(15, 19))
      program(owner, "No meio", [do_meio])

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

    test "omits program with no published workshop", %{owner: owner} do
      draft = insert(:workshop, organizer: owner, status: :draft, starts_at: at_day(10, 19))
      program(owner, "Só rascunho", [draft])

      assert Workshops.list_agenda(period: :upcoming) == []
    end

    test "omits draft program but keeps its published workshop", %{owner: owner} do
      w = insert(:workshop, organizer: owner, starts_at: at_day(10, 19))
      {:ok, p} = Workshops.create_program(owner, %{title: "Ainda montando"})
      {:ok, _} = Workshops.attach_workshop(p, owner, w.id)

      assert [%{kind: :workshop}] = Workshops.list_agenda(period: :upcoming)
    end

    test "summary carries the date range of the whole festival", %{owner: owner} do
      first = insert(:workshop, organizer: owner, starts_at: at_day(20, 14))
      last = insert(:workshop, organizer: owner, starts_at: at_day(25, 22))
      program(owner, "Festival", [first, last])

      assert [%{summary: summary}] = Workshops.list_agenda(period: :upcoming)
      assert DateTime.compare(summary.starts_at, first.starts_at) == :eq
      assert DateTime.compare(summary.ends_at, last.starts_at) == :eq
    end
  end

  describe "workshop attached to an unpublished program" do
    test "draft program does not swallow an already announced workshop", %{owner: owner} do
      w = insert(:workshop, organizer: owner, title: "Já anunciado", starts_at: at_day(10, 19))
      {:ok, p} = Workshops.create_program(owner, %{title: "Ainda montando"})
      {:ok, _} = Workshops.attach_workshop(p, owner, w.id)

      itens = Workshops.list_agenda(period: :upcoming)

      assert tipos(itens) == [:workshop]
      assert hd(itens).workshop.id == w.id
    end

    test "cancelled program returns its workshops to the agenda", %{owner: owner} do
      w = insert(:workshop, organizer: owner, title: "Continua de pé", starts_at: at_day(10, 19))
      p = program(owner, "Cancelada depois", [w])
      {:ok, _} = Workshops.cancel_program(owner, p)

      itens = Workshops.list_agenda(period: :upcoming)

      assert tipos(itens) == [:workshop]
      assert hd(itens).workshop.id == w.id
    end

    test "moving a program back to draft also returns its workshops", %{owner: owner} do
      w = insert(:workshop, organizer: owner, starts_at: at_day(10, 19))
      p = program(owner, "Publicada e despublicada", [w])
      {:ok, _} = Workshops.update_program(owner, p, %{title: "Mesma"})

      assert [%{kind: :program}] = Workshops.list_agenda(period: :upcoming)
    end
  end

  describe "list_agenda/1 with period filter" do
    test "program enters the period through the dates of its workshops", %{owner: owner} do
      this_year = insert(:workshop, organizer: owner, starts_at: at_day(200, 19))
      program(owner, "Lá longe", [this_year])

      assert Workshops.list_agenda(period: :week) == []
      assert [%{kind: :program}] = Workshops.list_agenda(period: :upcoming)
    end

    test "past filter returns programs that already happened", %{owner: owner} do
      past_workshop = insert(:workshop, organizer: owner, starts_at: at_day(-10, 19))
      program(owner, "Já foi", [past_workshop])

      assert [%{kind: :program, program: p}] = Workshops.list_agenda(period: :past)
      assert p.title == "Já foi"
    end
  end

  describe "program summary" do
    test "counts the whole festival, not only the filtered period", %{owner: owner} do
      this_week = insert(:workshop, organizer: owner, starts_at: at_day(2, 19))

      later_one =
        for i <- 1..4, do: insert(:workshop, organizer: owner, starts_at: at_day(30 + i, 19))

      program(owner, "Festival longo", [this_week | later_one])

      assert [%{summary: summary}] = Workshops.list_agenda(period: :week)

      assert summary.count == 5
    end
  end

  describe "list_agenda/1 com busca" do
    test "search opens the program and finds the workshop inside it", %{owner: owner} do
      dentro =
        insert(:workshop, organizer: owner, title: "Pisada nordestina", starts_at: at_day(10, 19))

      program(owner, "Festival de Itaúnas", [dentro])

      itens = Workshops.list_agenda(period: :upcoming, search: "pisada")

      assert tipos(itens) == [:workshop]
      assert hd(itens).workshop.id == dentro.id
    end

    test "search finds the program by its own title", %{owner: owner} do
      dentro =
        insert(:workshop, organizer: owner, title: "Qualquer coisa", starts_at: at_day(10, 19))

      program(owner, "Festival de Itaúnas", [dentro])

      itens = Workshops.list_agenda(period: :upcoming, search: "itaúnas")

      assert Enum.any?(itens, &(&1.kind == :program))
    end

    test "search finds the program by the organizer name", %{owner: owner} do
      dentro = insert(:workshop, organizer: owner, starts_at: at_day(10, 19))
      program(owner, "Festival", [dentro])

      itens = Workshops.list_agenda(period: :upcoming, search: "tavano")

      assert Enum.any?(itens, &(&1.kind == :program))
    end

    test "search does not repeat: workshops of a matched program stay inside it", %{
      owner: owner
    } do
      manha =
        insert(:workshop, organizer: owner, title: "Itaúnas manhã", starts_at: at_day(10, 10))

      tarde =
        insert(:workshop, organizer: owner, title: "Itaúnas tarde", starts_at: at_day(10, 15))

      program(owner, "Festival de Itaúnas", [manha, tarde])

      itens = Workshops.list_agenda(period: :upcoming, search: "itaúnas")

      assert tipos(itens) == [:program]
    end

    test "workshop whose program does not match comes loose and names its program", %{
      owner: owner
    } do
      dentro =
        insert(:workshop, organizer: owner, title: "Xote nordestino", starts_at: at_day(10, 19))

      program(owner, "Festival de Itaúnas", [dentro])

      assert [item] = Workshops.list_agenda(period: :upcoming, search: "xote")
      assert item.kind == :workshop
      assert item.workshop.program.title == "Festival de Itaúnas"
    end

    test "search with no match returns an empty list", %{owner: owner} do
      w = insert(:workshop, organizer: owner, starts_at: at_day(10, 19))
      program(owner, "Festival", [w])

      assert Workshops.list_agenda(period: :upcoming, search: "xilofone") == []
    end
  end
end
