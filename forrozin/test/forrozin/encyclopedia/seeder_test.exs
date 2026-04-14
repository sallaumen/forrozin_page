defmodule Forrozin.Encyclopedia.SeederTest do
  use Forrozin.DataCase, async: false

  alias Forrozin.Encyclopedia
  alias Forrozin.Encyclopedia.{Category, TechnicalConcept, Step, Section, Seeder, Subsection}

  describe "seed!/0" do
    test "inserts categories" do
      Seeder.seed!()
      assert Repo.aggregate(Category, :count) > 0
    end

    test "inserts sections" do
      Seeder.seed!()
      assert Repo.aggregate(Section, :count) > 0
    end

    test "inserts subsections" do
      Seeder.seed!()
      assert Repo.aggregate(Subsection, :count) > 0
    end

    test "inserts steps" do
      Seeder.seed!()
      assert Repo.aggregate(Step, :count) > 0
    end

    test "inserts technical concepts" do
      Seeder.seed!()
      assert Repo.aggregate(TechnicalConcept, :count) > 0
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
      count_before = Repo.aggregate(Step, :count)
      assert Seeder.seed!() == :already_seeded
      assert Repo.aggregate(Category, :count) > 0
      assert Repo.aggregate(Step, :count) == count_before
    end
  end
end
