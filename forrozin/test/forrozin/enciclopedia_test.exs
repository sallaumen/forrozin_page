defmodule Forrozin.EnciclopediaTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Enciclopedia

  # ---------------------------------------------------------------------------
  # Categorias
  # ---------------------------------------------------------------------------

  describe "listar_categorias/0" do
    test "retorna lista vazia quando não há categorias" do
      assert Enciclopedia.listar_categorias() == []
    end

    test "retorna todas as categorias ordenadas por rótulo" do
      insert(:categoria, nome: "sacadas", rotulo: "Sacadas")
      insert(:categoria, nome: "bases", rotulo: "Bases")

      rotulos = Enciclopedia.listar_categorias() |> Enum.map(& &1.rotulo)

      assert rotulos == ["Bases", "Sacadas"]
    end
  end

  describe "buscar_categoria_por_nome/1" do
    test "retorna a categoria quando existe" do
      insert(:categoria, nome: "sacadas", rotulo: "Sacadas")
      assert {:ok, %{nome: "sacadas"}} = Enciclopedia.buscar_categoria_por_nome("sacadas")
    end

    test "retorna erro quando não existe" do
      assert {:error, :nao_encontrado} = Enciclopedia.buscar_categoria_por_nome("inexistente")
    end
  end

  # ---------------------------------------------------------------------------
  # Seções
  # ---------------------------------------------------------------------------

  describe "listar_secoes/0" do
    test "retorna lista vazia quando não há seções" do
      assert Enciclopedia.listar_secoes() == []
    end

    test "retorna seções ordenadas por posição" do
      insert(:secao, titulo: "Sacadas", posicao: 2)
      insert(:secao, titulo: "Bases", posicao: 1)

      titulos = Enciclopedia.listar_secoes() |> Enum.map(& &1.titulo)

      assert titulos == ["Bases", "Sacadas"]
    end
  end

  describe "listar_secoes_com_passos/0" do
    test "retorna seções com passos e subseções pré-carregados" do
      secao = insert(:secao)
      insert(:passo, secao: secao, codigo: "BF", nome: "Base frontal")

      [resultado] = Enciclopedia.listar_secoes_com_passos()

      assert resultado.id == secao.id
      assert length(resultado.passos) == 1
      assert hd(resultado.passos).codigo == "BF"
    end

    test "não inclui passos wip para leitura pública" do
      secao = insert(:secao)
      insert(:passo, secao: secao, codigo: "BF", nome: "Base frontal", wip: false)
      insert(:passo, secao: secao, codigo: "HF-SRS", nome: "Sacada Rotativa", wip: true)

      [resultado] = Enciclopedia.listar_secoes_com_passos()

      codigos = Enum.map(resultado.passos, & &1.codigo)
      assert "BF" in codigos
      refute "HF-SRS" in codigos
    end

    test "não inclui passos com status rascunho" do
      secao = insert(:secao)
      insert(:passo, secao: secao, codigo: "BF", nome: "Base frontal", status: "publicado")
      insert(:passo, secao: secao, codigo: "BQ", nome: "Base quadrada", status: "rascunho")

      [resultado] = Enciclopedia.listar_secoes_com_passos()

      codigos = Enum.map(resultado.passos, & &1.codigo)
      assert "BF" in codigos
      refute "BQ" in codigos
    end
  end

  # ---------------------------------------------------------------------------
  # Passos
  # ---------------------------------------------------------------------------

  describe "buscar_passo_por_codigo/1" do
    test "retorna o passo quando existe e é público" do
      insert(:passo, codigo: "BF", nome: "Base frontal")

      assert {:ok, %{codigo: "BF"}} = Enciclopedia.buscar_passo_por_codigo("BF")
    end

    test "retorna erro para passo wip" do
      insert(:passo, codigo: "HF-SRS", nome: "Sacada Rotativa", wip: true)

      assert {:error, :nao_encontrado} = Enciclopedia.buscar_passo_por_codigo("HF-SRS")
    end

    test "retorna erro quando não existe" do
      assert {:error, :nao_encontrado} = Enciclopedia.buscar_passo_por_codigo("INEXISTENTE")
    end
  end

  describe "buscar_passos/1" do
    test "retorna passos que contêm o termo no nome" do
      insert(:passo, codigo: "BF", nome: "Base frontal")
      insert(:passo, codigo: "BQ", nome: "Base quadrada")
      insert(:passo, codigo: "SC", nome: "Sacada simples")

      resultados = Enciclopedia.buscar_passos("base")

      codigos = Enum.map(resultados, & &1.codigo)
      assert "BF" in codigos
      assert "BQ" in codigos
      refute "SC" in codigos
    end

    test "busca é case-insensitive" do
      insert(:passo, codigo: "BF", nome: "Base frontal")

      resultados = Enciclopedia.buscar_passos("BASE")

      assert length(resultados) == 1
    end

    test "não retorna passos wip na busca pública" do
      insert(:passo, codigo: "BF", nome: "Base frontal", wip: false)
      insert(:passo, codigo: "HF-SRS", nome: "Base rotativa suspensa", wip: true)

      resultados = Enciclopedia.buscar_passos("base")

      codigos = Enum.map(resultados, & &1.codigo)
      assert "BF" in codigos
      refute "HF-SRS" in codigos
    end

    test "retorna lista vazia quando não há correspondência" do
      insert(:passo, codigo: "BF", nome: "Base frontal")

      assert Enciclopedia.buscar_passos("xyzzyqwerty_inexistente") == []
    end
  end

  # ---------------------------------------------------------------------------
  # Grafo
  # ---------------------------------------------------------------------------

  describe "listar_grafo/1" do
    test "retorna mapa com chaves :nos e :arestas" do
      grafo = Enciclopedia.listar_grafo()
      assert Map.has_key?(grafo, :nos)
      assert Map.has_key?(grafo, :arestas)
    end

    test ":nos contém passos públicos com categoria precarregada" do
      cat = insert(:categoria)
      insert(:passo, codigo: "BF-TEST", nome: "Base frontal", categoria: cat)
      grafo = Enciclopedia.listar_grafo()
      no = Enum.find(grafo.nos, fn n -> n.codigo == "BF-TEST" end)
      assert no != nil
      assert no.codigo == "BF-TEST"
      assert no.categoria.id == cat.id
    end

    test ":arestas contém conexões com passo_origem e passo_destino precarregados" do
      passo_a = insert(:passo, codigo: "BF")
      passo_b = insert(:passo, codigo: "SC")
      insert(:conexao, passo_origem: passo_a, passo_destino: passo_b, tipo: "saida")
      grafo = Enciclopedia.listar_grafo()
      assert length(grafo.arestas) == 1
      [aresta] = grafo.arestas
      assert aresta.passo_origem.codigo == "BF"
      assert aresta.passo_destino.codigo == "SC"
    end

    test "não inclui passos wip nos nós" do
      insert(:passo, codigo: "BF", wip: false)
      insert(:passo, codigo: "HF-SRS", wip: true)
      grafo = Enciclopedia.listar_grafo()
      codigos = Enum.map(grafo.nos, & &1.codigo)
      assert "BF" in codigos
      refute "HF-SRS" in codigos
    end

    test "não inclui arestas onde passo_destino é wip" do
      passo_pub = insert(:passo, codigo: "BF", wip: false)
      passo_wip = insert(:passo, codigo: "HF-SRS", wip: true)
      insert(:conexao, passo_origem: passo_pub, passo_destino: passo_wip, tipo: "saida")
      grafo = Enciclopedia.listar_grafo()
      assert grafo.arestas == []
    end

    test ":arestas incluem rotulo quando presente" do
      passo_a = insert(:passo, codigo: "ARM-D")
      passo_b = insert(:passo, codigo: "TR-ARM")
      insert(:conexao, passo_origem: passo_a, passo_destino: passo_b, tipo: "saida", rotulo: "Trava Armada")
      grafo = Enciclopedia.listar_grafo()
      [aresta] = grafo.arestas
      assert aresta.rotulo == "Trava Armada"
    end

    test "não inclui arestas onde passo_origem é wip" do
      passo_wip = insert(:passo, codigo: "HF-SRS", wip: true)
      passo_pub = insert(:passo, codigo: "BF", wip: false)
      insert(:conexao, passo_origem: passo_wip, passo_destino: passo_pub, tipo: "saida")
      grafo = Enciclopedia.listar_grafo()
      assert grafo.arestas == []
    end

    test "com [admin: true] inclui passos wip nos nós" do
      insert(:passo, codigo: "BF", wip: false)
      insert(:passo, codigo: "HF-SRS", wip: true)
      grafo = Enciclopedia.listar_grafo(admin: true)
      codigos = Enum.map(grafo.nos, & &1.codigo)
      assert "BF" in codigos
      assert "HF-SRS" in codigos
    end
  end

  # ---------------------------------------------------------------------------
  # Conceitos Técnicos
  # ---------------------------------------------------------------------------

  describe "listar_conceitos_tecnicos/0" do
    test "retorna lista vazia quando não há conceitos" do
      assert Enciclopedia.listar_conceitos_tecnicos() == []
    end

    test "retorna conceitos ordenados por título" do
      insert(:conceito_tecnico, titulo: "Transferência de peso")
      insert(:conceito_tecnico, titulo: "Elástico")

      titulos = Enciclopedia.listar_conceitos_tecnicos() |> Enum.map(& &1.titulo)

      assert titulos == ["Elástico", "Transferência de peso"]
    end
  end
end
