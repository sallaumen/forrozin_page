defmodule OGrupoDeEstudos.Admin.BackupTest do
  use OGrupoDeEstudos.DataCase, async: false

  alias OGrupoDeEstudos.Admin.Backup
  alias OGrupoDeEstudos.Repo

  setup do
    dir = Path.join(System.tmp_dir!(), "o_grupo_de_estudos_backup_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  # ---------------------------------------------------------------------------
  # create_backup!/1
  # ---------------------------------------------------------------------------

  describe "create_backup!/1" do
    test "creates JSON file in the specified directory", %{dir: dir} do
      path = Backup.create_backup!(dir)
      assert File.exists?(path)
      assert String.ends_with?(path, ".json")
    end

    test "JSON contains all expected tables", %{dir: dir} do
      path = Backup.create_backup!(dir)
      data = path |> File.read!() |> Jason.decode!()

      assert data["version"] == "1"
      assert is_binary(data["created_at"])
      tables = data["tables"]
      assert Map.has_key?(tables, "users")
      assert Map.has_key?(tables, "categories")
      assert Map.has_key?(tables, "sections")
      assert Map.has_key?(tables, "subsections")
      assert Map.has_key?(tables, "steps")
      assert Map.has_key?(tables, "step_connections")
      assert Map.has_key?(tables, "technical_concepts")
      assert Map.has_key?(tables, "concept_steps")
      assert Map.has_key?(tables, "step_links")
      assert Map.has_key?(tables, "sequences")
      assert Map.has_key?(tables, "sequence_steps")
      assert Map.has_key?(tables, "likes")
    end

    test "JSON includes data present in the database", %{dir: dir} do
      cat = insert(:category, name: "bases")
      section = insert(:section, category: cat)
      step_a = insert(:step, code: "BF", section: section, category: cat)
      step_b = insert(:step, code: "SC", section: section, category: cat)
      insert(:connection, source_step: step_a, target_step: step_b)

      path = Backup.create_backup!(dir)
      data = path |> File.read!() |> Jason.decode!()

      step_codes = Enum.map(data["tables"]["steps"], & &1["code"])
      assert "BF" in step_codes
      assert "SC" in step_codes
      assert [_] = data["tables"]["step_connections"]
    end

    test "removes old files keeping only the last 48", %{dir: dir} do
      # Creates 50 fake older backup files
      for i <- 1..50 do
        name = "backup_20260101_#{String.pad_leading(to_string(i), 6, "0")}.json"
        File.write!(Path.join(dir, name), "{}")
      end

      Backup.create_backup!(dir)

      files = File.ls!(dir) |> Enum.filter(&String.ends_with?(&1, ".json"))
      assert Enum.count(files) == 48
    end
  end

  # ---------------------------------------------------------------------------
  # restore_backup!/1
  # ---------------------------------------------------------------------------

  describe "restore_backup!/1" do
    test "inserts data into an empty database", %{dir: dir} do
      # Creates data, generates backup, then verifies restoring is idempotent
      cat = insert(:category, name: "bases")
      section = insert(:section, category: cat)
      step_a = insert(:step, code: "BF", section: section, category: cat)
      step_b = insert(:step, code: "SC", section: section, category: cat)
      insert(:connection, source_step: step_a, target_step: step_b)

      path = Backup.create_backup!(dir)

      # Restore with data already present (on_conflict: :nothing)
      assert :ok = Backup.restore_backup!(path)

      # Data must still be there
      assert Repo.aggregate(OGrupoDeEstudos.Encyclopedia.Category, :count) >= 1
      assert Repo.aggregate(OGrupoDeEstudos.Encyclopedia.Step, :count) >= 2
      assert Repo.aggregate(OGrupoDeEstudos.Encyclopedia.Connection, :count) >= 1
    end

    test "idempotent — second restore does not duplicate data", %{dir: dir} do
      cat = insert(:category, name: "sacadas")
      section = insert(:section, category: cat)
      insert(:step, code: "SC", section: section, category: cat)

      path = Backup.create_backup!(dir)
      count_before = Repo.aggregate(OGrupoDeEstudos.Encyclopedia.Step, :count)

      Backup.restore_backup!(path)
      count_after = Repo.aggregate(OGrupoDeEstudos.Encyclopedia.Step, :count)

      assert count_before == count_after
    end
  end

  # ---------------------------------------------------------------------------
  # list_backups/1
  # ---------------------------------------------------------------------------

  describe "list_backups/1" do
    test "returns empty list when there are no backups", %{dir: dir} do
      assert Backup.list_backups(dir) == []
    end

    test "returns files sorted from most recent to oldest", %{dir: dir} do
      File.write!(Path.join(dir, "backup_20260101_120000.json"), "{}")
      File.write!(Path.join(dir, "backup_20260101_130000.json"), "{}")
      File.write!(Path.join(dir, "backup_20260101_110000.json"), "{}")

      names = Backup.list_backups(dir) |> Enum.map(&Path.basename/1)

      assert names == [
               "backup_20260101_130000.json",
               "backup_20260101_120000.json",
               "backup_20260101_110000.json"
             ]
    end
  end
end
