defmodule Forrozin.Workers.PeriodicBackupTest do
  use Forrozin.DataCase, async: false

  alias Forrozin.Workers.PeriodicBackup

  setup do
    dir =
      Path.join(System.tmp_dir!(), "forrozin_backup_worker_#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  describe "perform/1" do
    test "returns :ok and creates backup file", %{dir: dir} do
      assert :ok = perform_job(PeriodicBackup, %{"dir" => dir})
      files = File.ls!(dir) |> Enum.filter(&String.ends_with?(&1, ".json"))
      assert length(files) == 1
    end
  end
end
