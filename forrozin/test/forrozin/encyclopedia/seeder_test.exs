defmodule Forrozin.Encyclopedia.SeederTest do
  use Forrozin.DataCase, async: true

  alias Forrozin.Encyclopedia
  alias Forrozin.Encyclopedia.{Category, TechnicalConcept, Step, Section, Seeder, Subsection}

  describe "seed!/0" do
    test "inserts all 11 categories" do
      Seeder.seed!()
      assert Repo.aggregate(Category, :count) == 11
    end

    test "inserts all 21 sections" do
      Seeder.seed!()
      assert Repo.aggregate(Section, :count) == 21
    end

    test "inserts all 8 subsections" do
      Seeder.seed!()
      assert Repo.aggregate(Subsection, :count) == 8
    end

    test "inserts more than 120 unique steps" do
      Seeder.seed!()
      assert Repo.aggregate(Step, :count) > 120
    end

    test "inserts all 7 technical concepts" do
      Seeder.seed!()
      assert Repo.aggregate(TechnicalConcept, :count) == 7
    end

    test "step BF is public (not wip, status published)" do
      Seeder.seed!()
      assert {:ok, step} = Encyclopedia.get_step_by_code("BF")
      assert step.name == "Base frontal"
      refute step.wip
    end

    test "HF-* steps are wip and do not appear in public reads" do
      Seeder.seed!()
      assert {:error, :not_found} = Encyclopedia.get_step_by_code("HF-SRS")
      step = Repo.get_by(Step, code: "HF-SRS")
      assert step != nil
      assert step.wip == true
    end

    test "steps with image have image_path populated" do
      Seeder.seed!()
      step = Repo.get_by(Step, code: "HF-CAI")
      assert step.image_path == "images/HF-CAI.jpg"
    end

    test "idempotent — second call does not duplicate data" do
      Seeder.seed!()
      assert Seeder.seed!() == :already_seeded
      assert Repo.aggregate(Category, :count) == 11
      assert Repo.aggregate(Step, :count) > 120
    end
  end
end
