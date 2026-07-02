defmodule OGrupoDeEstudos.Workers.StartupScriptsTest do
  use OGrupoDeEstudos.DataCase, async: false

  alias OGrupoDeEstudos.StartupScriptRecord
  alias OGrupoDeEstudos.Workers.StartupScripts

  describe "perform/1" do
    test "runs the startup scripts and records completion" do
      assert :ok = perform_job(StartupScripts, %{})

      records = Repo.all(StartupScriptRecord)
      assert records != []
      assert Enum.all?(records, &(&1.result != "running"))
    end

    test "is idempotent for run-once scripts" do
      assert :ok = perform_job(StartupScripts, %{})
      count = Repo.aggregate(StartupScriptRecord, :count)

      assert :ok = perform_job(StartupScripts, %{})
      assert Repo.aggregate(StartupScriptRecord, :count) == count
    end
  end

  describe "enqueue/0" do
    test "inserts a job" do
      assert {:ok, %Oban.Job{}} = StartupScripts.enqueue()
    end
  end
end
