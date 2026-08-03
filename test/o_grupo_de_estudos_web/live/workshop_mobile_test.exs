defmodule OGrupoDeEstudosWeb.WorkshopMobileTest do
  @moduledoc """
  O que o celular vê primeiro, e em português.

  Numa tela de 375px as duas colunas do desktop viram uma pilha, e a ordem do
  DOM passa a ser a ordem de leitura. Estes testes prendem as decisões que a
  auditoria em 375px derrubou: preço antes do conteúdo, e nenhum controle
  nativo do navegador falando inglês.
  """

  use OGrupoDeEstudosWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OGrupoDeEstudos.{Brazil, Workshops}

  defp em(dias, hora \\ 14) do
    Brazil.today()
    |> Date.add(dias)
    |> DateTime.new!(Time.new!(hora, 0, 0), "Etc/UTC")
    |> Brazil.to_utc()
    |> DateTime.truncate(:second)
  end

  defp publicado(organizer, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          title: "Workshop de sacadas",
          description: "Conteúdo do workshop.",
          location: "Curitiba",
          starts_at: em(7),
          price_cents: 18_000
        },
        overrides
      )

    {:ok, w} = Workshops.create_workshop(organizer, attrs)
    {:ok, w} = Workshops.publish_workshop(organizer, w)
    w
  end

  describe "ordem de leitura no celular" do
    test "preço e inscrição vêm ANTES do conteúdo", %{conn: conn} do
      # No desktop a caixa fica na coluna da direita; no celular a coluna some
      # e sobra a ordem do DOM. Com a caixa depois das seções, quem abre o link
      # rola a conversa inteira antes de saber quanto custa (auditoria em
      # 375px: a caixa aparecia a 79% da altura da página).
      dono = insert(:user)
      workshop = publicado(dono)
      {:ok, _} = Workshops.enroll(workshop, insert(:user))

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{workshop.slug}")

      assert posicao(html, "R$ 180") < posicao(html, "Conversa")
      assert posicao(html, "Fazer inscrição") < posicao(html, "Conversa")
    end

    test "no desktop a caixa volta para a coluna da direita", %{conn: conn} do
      # A ordem do DOM é do celular; o desktop reordena por CSS. Sem a classe
      # de reordenação, o preço sairia à esquerda e a descrição à direita.
      dono = insert(:user)
      workshop = publicado(dono)

      {:ok, _lv, html} = live(log_in_user(conn, insert(:user)), ~p"/workshops/#{workshop.slug}")

      assert html =~ "lg:order-2"
      assert html =~ "lg:order-1"
    end
  end

  describe "controles em português" do
    test "a galeria não mostra o botão nativo do navegador", %{conn: conn} do
      # O input de arquivo cru escreve "Choose File" e "No file chosen" em
      # inglês, no meio de uma página em português.
      dono = insert(:user)
      workshop = publicado(dono)
      aluna = insert(:user)
      {:ok, _} = Workshops.enroll(workshop, aluna)

      {:ok, _lv, html} = live(log_in_user(conn, aluna), ~p"/workshops/#{workshop.slug}")

      assert html =~ "Escolher foto ou vídeo"
      assert html =~ "sr-only"
    end

    test "o flyer também tem rótulo próprio", %{conn: conn} do
      dono = insert(:user)
      workshop = publicado(dono)

      {:ok, _lv, html} =
        live(log_in_user(conn, dono), ~p"/study/workshops/#{workshop.slug}/editar")

      assert html =~ "Escolher imagem"
    end
  end

  describe "linha de inscrito no painel" do
    test "identidade e ações ficam em faixas separadas no celular", %{conn: conn} do
      # Com tudo na mesma linha, o nome era espremido em três linhas e os
      # botões caíam de um jeito em quem já pagou e de outro em quem não pagou.
      dono = insert(:user)
      workshop = publicado(dono)
      {:ok, _} = Workshops.enroll(workshop, insert(:user, name: "Maria Aluna"))

      {:ok, _lv, html} = live(log_in_user(conn, dono), ~p"/workshops/#{workshop.slug}/gerenciar")

      assert html =~ "basis-full"
      assert html =~ "Maria Aluna"
    end
  end

  defp posicao(html, trecho) do
    case :binary.match(html, trecho) do
      {inicio, _} -> inicio
      :nomatch -> flunk("não achei #{inspect(trecho)} no HTML")
    end
  end
end
