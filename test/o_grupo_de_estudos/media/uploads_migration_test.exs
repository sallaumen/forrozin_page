defmodule OGrupoDeEstudos.Media.UploadsMigrationTest do
  @moduledoc """
  Move from the local volume to object storage: copy every file to the port,
  then rewrite the stored public URLs. Private keys are already relative and
  do not change.
  """

  use OGrupoDeEstudos.DataCase, async: false

  import Mox
  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Media.ObjectStorage
  alias OGrupoDeEstudos.Media.UploadsMigration

  setup :verify_on_exit!

  setup do
    Application.put_env(:o_grupo_de_estudos, ObjectStorage, adapter: ObjectStorage.Mock)
    on_exit(fn -> Application.delete_env(:o_grupo_de_estudos, ObjectStorage) end)

    source = Path.join(System.tmp_dir!(), "migracao_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(source, "avatars"))
    File.mkdir_p!(Path.join(source, "workshop_media"))
    File.write!(Path.join(source, "avatars/u1_9.png"), "avatar")
    File.write!(Path.join(source, "workshop_media/v.mp4"), "video")
    on_exit(fn -> File.rm_rf!(source) end)

    %{source: source}
  end

  test "copies each disk file to the port under its relative key", ctx do
    expect(ObjectStorage.Mock, :put, 2, fn key, path ->
      assert key in ["avatars/u1_9.png", "workshop_media/v.mp4"]
      assert File.exists?(path)
      :ok
    end)

    result = UploadsMigration.run(ctx.source)

    assert result.arquivos == 2
    assert result.falhas == []
  end

  test "rewrites avatar_path and flyer_path to the provider public URL", ctx do
    stub(ObjectStorage.Mock, :put, fn _key, _path -> :ok end)

    stub(ObjectStorage.Mock, :public_url, fn key ->
      "https://midia.teste.dev/" <> key
    end)

    pessoa = insert(:user, avatar_path: "/uploads/avatars/u1_9.png")
    workshop = insert(:workshop, flyer_path: "/uploads/flyers/f.png")

    result = UploadsMigration.run(ctx.source)

    assert Repo.reload!(pessoa).avatar_path == "https://midia.teste.dev/avatars/u1_9.png"
    assert Repo.reload!(workshop).flyer_path == "https://midia.teste.dev/flyers/f.png"
    assert result.reescritos == 2
  end

  test "URL outside the volume is left alone", ctx do
    stub(ObjectStorage.Mock, :put, fn _key, _path -> :ok end)
    stub(ObjectStorage.Mock, :public_url, fn key -> "https://midia.teste.dev/" <> key end)

    de_fora = insert(:user, avatar_path: "https://outro-lugar.com/foto.png")
    sem_avatar = insert(:user)

    UploadsMigration.run(ctx.source)

    assert Repo.reload!(de_fora).avatar_path == "https://outro-lugar.com/foto.png"
    assert is_nil(Repo.reload!(sem_avatar).avatar_path)
  end

  test "failed file enters the report and holds back the URL rewrite", ctx do
    expect(ObjectStorage.Mock, :put, 2, fn key, _path ->
      if key =~ "v.mp4", do: {:error, :timeout}, else: :ok
    end)

    pessoa = insert(:user, avatar_path: "/uploads/avatars/u1_9.png")

    result = UploadsMigration.run(ctx.source)

    assert result.arquivos == 1
    assert [{"workshop_media/v.mp4", :timeout}] = result.falhas
    assert result.reescritos == 0
    assert Repo.reload!(pessoa).avatar_path == "/uploads/avatars/u1_9.png"
  end

  test "empty source folder does not blow up" do
    vazia = Path.join(System.tmp_dir!(), "vazia_#{System.unique_integer([:positive])}")
    File.mkdir_p!(vazia)
    on_exit(fn -> File.rm_rf!(vazia) end)

    assert %{arquivos: 0, falhas: []} = UploadsMigration.run(vazia)
  end
end
