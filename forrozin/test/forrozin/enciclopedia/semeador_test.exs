defmodule Forrozin.Enciclopedia.SemeadorTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Enciclopedia
  alias Forrozin.Enciclopedia.{Categoria, ConceitoTecnico, Passo, Secao, Semeador, Subsecao}

  describe "semear!/0" do
    test "insere as 11 categorias" do
      Semeador.semear!()
      assert Repo.aggregate(Categoria, :count) == 11
    end

    test "insere as 21 seções" do
      Semeador.semear!()
      assert Repo.aggregate(Secao, :count) == 21
    end

    test "insere as 8 subseções" do
      Semeador.semear!()
      assert Repo.aggregate(Subsecao, :count) == 8
    end

    test "insere mais de 120 passos únicos" do
      Semeador.semear!()
      assert Repo.aggregate(Passo, :count) > 120
    end

    test "insere os 7 conceitos técnicos" do
      Semeador.semear!()
      assert Repo.aggregate(ConceitoTecnico, :count) == 7
    end

    test "passo BF é público (não wip, status publicado)" do
      Semeador.semear!()
      assert {:ok, passo} = Enciclopedia.buscar_passo_por_codigo("BF")
      assert passo.nome == "Base frontal"
      refute passo.wip
    end

    test "passos HF-* são wip e não aparecem na leitura pública" do
      Semeador.semear!()
      assert {:error, :nao_encontrado} = Enciclopedia.buscar_passo_por_codigo("HF-SRS")
      passo = Repo.get_by(Passo, codigo: "HF-SRS")
      assert passo != nil
      assert passo.wip == true
    end

    test "passos com imagem têm caminho_imagem preenchido" do
      Semeador.semear!()
      passo = Repo.get_by(Passo, codigo: "HF-CAI")
      assert passo.caminho_imagem == "images/HF-CAI.jpg"
    end

    test "é idempotente — segunda chamada não duplica dados" do
      Semeador.semear!()
      assert Semeador.semear!() == :already_seeded
      assert Repo.aggregate(Categoria, :count) == 11
      assert Repo.aggregate(Passo, :count) > 120
    end
  end
end
