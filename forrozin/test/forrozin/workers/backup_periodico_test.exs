defmodule Forrozin.Workers.BackupPeriodicoTest do
  use Forrozin.DataCase, async: false

  alias Forrozin.Workers.BackupPeriodico

  setup do
    dir =
      Path.join(System.tmp_dir!(), "forrozin_backup_worker_#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  describe "perform/1" do
    test "retorna :ok e cria arquivo de backup", %{dir: dir} do
      assert :ok = perform_job(BackupPeriodico, %{"dir" => dir})
      arquivos = File.ls!(dir) |> Enum.filter(&String.ends_with?(&1, ".json"))
      assert length(arquivos) == 1
    end
  end
end
