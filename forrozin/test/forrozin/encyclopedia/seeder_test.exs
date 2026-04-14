defmodule Forrozin.Encyclopedia.SeederTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Encyclopedia
  alias Forrozin.Encyclopedia.{Category, TechnicalConcept, Step, Section, Seeder, Subsection}

  describe "seed!/0" do
    test "insere as 11 categorias" do
      Seeder.seed!()
      assert Repo.aggregate(Category, :count) == 11
    end

    test "insere as 21 seções" do
      Seeder.seed!()
      assert Repo.aggregate(Section, :count) == 21
    end

    test "insere as 8 subseções" do
      Seeder.seed!()
      assert Repo.aggregate(Subsection, :count) == 8
    end

    test "insere mais de 120 passos únicos" do
      Seeder.seed!()
      assert Repo.aggregate(Step, :count) > 120
    end

    test "insere os 7 conceitos técnicos" do
      Seeder.seed!()
      assert Repo.aggregate(TechnicalConcept, :count) == 7
    end

    test "passo BF é público (não wip, status published)" do
      Seeder.seed!()
      assert {:ok, step} = Encyclopedia.get_step_by_code("BF")
      assert step.name == "Base frontal"
      refute step.wip
    end

    test "passos HF-* são wip e não aparecem na leitura pública" do
      Seeder.seed!()
      assert {:error, :not_found} = Encyclopedia.get_step_by_code("HF-SRS")
      step = Repo.get_by(Step, code: "HF-SRS")
      assert step != nil
      assert step.wip == true
    end

    test "passos com imagem têm image_path preenchido" do
      Seeder.seed!()
      step = Repo.get_by(Step, code: "HF-CAI")
      assert step.image_path == "images/HF-CAI.jpg"
    end

    test "é idempotente — segunda chamada não duplica dados" do
      Seeder.seed!()
      assert Seeder.seed!() == :already_seeded
      assert Repo.aggregate(Category, :count) == 11
      assert Repo.aggregate(Step, :count) > 120
    end
  end
end
