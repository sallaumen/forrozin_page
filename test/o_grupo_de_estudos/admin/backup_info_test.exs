defmodule OGrupoDeEstudos.Admin.BackupInfoTest do
  @moduledoc """
  Unit tests for the `backup_info/1` and `parse_backup_timestamp/1` helpers
  added to `OGrupoDeEstudos.Admin.Backup`.
  """

  use ExUnit.Case, async: true

  alias OGrupoDeEstudos.Admin.Backup

  # ---------------------------------------------------------------------------
  # parse_backup_timestamp/1
  # ---------------------------------------------------------------------------

  describe "parse_backup_timestamp/1" do
    test "parses a well-formed backup filename" do
      assert %NaiveDateTime{
               year: 2026,
               month: 4,
               day: 15,
               hour: 12,
               minute: 0,
               second: 0
             } = Backup.parse_backup_timestamp("backup_20260415_120000.json")
    end

    test "returns nil for a filename that does not match the pattern" do
      assert is_nil(Backup.parse_backup_timestamp("something_else.json"))
    end

    test "returns nil for a completely unrelated string" do
      assert is_nil(Backup.parse_backup_timestamp("notabackup"))
    end

    test "parses timestamps at midnight correctly" do
      result = Backup.parse_backup_timestamp("backup_20260101_000000.json")
      assert %NaiveDateTime{hour: 0, minute: 0, second: 0} = result
    end

    test "parses timestamps at end of day correctly" do
      result = Backup.parse_backup_timestamp("backup_20261231_235959.json")

      assert %NaiveDateTime{year: 2026, month: 12, day: 31, hour: 23, minute: 59, second: 59} =
               result
    end
  end

  # ---------------------------------------------------------------------------
  # backup_info/1
  # ---------------------------------------------------------------------------

  describe "backup_info/1" do
    setup do
      dir = Path.join(System.tmp_dir!(), "backup_info_test_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)
      %{dir: dir}
    end

    test "returns a map with path, filename, size, and timestamp for an existing file", %{
      dir: dir
    } do
      filename = "backup_20260415_130000.json"
      path = Path.join(dir, filename)
      File.write!(path, ~s({"version":"1"}))

      info = Backup.backup_info(path)

      assert info.path == path
      assert info.filename == filename
      assert info.size > 0
      assert %NaiveDateTime{year: 2026, month: 4, day: 15} = info.timestamp
    end

    test "returns nil for a non-existent file", %{dir: dir} do
      assert is_nil(Backup.backup_info(Path.join(dir, "ghost.json")))
    end

    test "reports the correct file size", %{dir: dir} do
      content = String.duplicate("x", 1024)
      path = Path.join(dir, "backup_20260415_140000.json")
      File.write!(path, content)

      info = Backup.backup_info(path)
      assert info.size == 1024
    end

    test "timestamp is nil when filename does not match pattern", %{dir: dir} do
      path = Path.join(dir, "oddname.json")
      File.write!(path, "{}")

      info = Backup.backup_info(path)
      assert is_nil(info.timestamp)
    end
  end
end
