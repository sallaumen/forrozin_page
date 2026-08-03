defmodule OGrupoDeEstudos.Media.UploadsMigrationTest do
  @moduledoc """
  Mudança do volume local para o storage de objetos.

  Duas metades: copiar cada arquivo do disco para a porta, e reescrever no
  banco as URLs públicas gravadas (`/uploads/...` vira a URL do provider).
  As chaves privadas (galeria) não mudam: são relativas desde o começo.
  """

  # async: false — troca o adapter da porta, que é config global.
  use OGrupoDeEstudos.DataCase, async: false

  import Mox
  import OGrupoDeEstudos.Factory

  alias OGrupoDeEstudos.Media.ObjectStorage
  alias OGrupoDeEstudos.Media.UploadsMigration

  setup :verify_on_exit!

  setup do
    Application.put_env(:o_grupo_de_estudos, ObjectStorage, adapter: ObjectStorage.Mock)
    on_exit(fn -> Application.delete_env(:o_grupo_de_estudos, ObjectStorage) end)

    origem = Path.join(System.tmp_dir!(), "migracao_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(origem, "avatars"))
    File.mkdir_p!(Path.join(origem, "workshop_media"))
    File.write!(Path.join(origem, "avatars/u1_9.png"), "avatar")
    File.write!(Path.join(origem, "workshop_media/v.mp4"), "video")
    on_exit(fn -> File.rm_rf!(origem) end)

    %{origem: origem}
  end

  test "copia cada arquivo do disco para a porta, com a chave relativa", ctx do
    expect(ObjectStorage.Mock, :put, 2, fn chave, caminho ->
      assert chave in ["avatars/u1_9.png", "workshop_media/v.mp4"]
      assert File.exists?(caminho)
      :ok
    end)

    resultado = UploadsMigration.run(ctx.origem)

    assert resultado.arquivos == 2
    assert resultado.falhas == []
  end

  test "reescreve avatar_path e flyer_path para a URL pública do provider", ctx do
    stub(ObjectStorage.Mock, :put, fn _chave, _caminho -> :ok end)

    stub(ObjectStorage.Mock, :public_url, fn chave ->
      "https://midia.teste.dev/" <> chave
    end)

    pessoa = insert(:user, avatar_path: "/uploads/avatars/u1_9.png")
    workshop = insert(:workshop, flyer_path: "/uploads/flyers/f.png")

    resultado = UploadsMigration.run(ctx.origem)

    assert Repo.reload!(pessoa).avatar_path == "https://midia.teste.dev/avatars/u1_9.png"
    assert Repo.reload!(workshop).flyer_path == "https://midia.teste.dev/flyers/f.png"
    assert resultado.reescritos == 2
  end

  test "URL que não é do volume fica em paz", ctx do
    stub(ObjectStorage.Mock, :put, fn _chave, _caminho -> :ok end)
    stub(ObjectStorage.Mock, :public_url, fn chave -> "https://midia.teste.dev/" <> chave end)

    de_fora = insert(:user, avatar_path: "https://outro-lugar.com/foto.png")
    sem_avatar = insert(:user)

    UploadsMigration.run(ctx.origem)

    assert Repo.reload!(de_fora).avatar_path == "https://outro-lugar.com/foto.png"
    assert is_nil(Repo.reload!(sem_avatar).avatar_path)
  end

  test "arquivo que falha não derruba a migração: entra no relatório", ctx do
    expect(ObjectStorage.Mock, :put, 2, fn chave, _caminho ->
      if chave =~ "v.mp4", do: {:error, :timeout}, else: :ok
    end)

    resultado = UploadsMigration.run(ctx.origem)

    assert resultado.arquivos == 1
    assert [{"workshop_media/v.mp4", :timeout}] = resultado.falhas
  end

  test "pasta de origem vazia não explode" do
    vazia = Path.join(System.tmp_dir!(), "vazia_#{System.unique_integer([:positive])}")
    File.mkdir_p!(vazia)
    on_exit(fn -> File.rm_rf!(vazia) end)

    assert %{arquivos: 0, falhas: []} = UploadsMigration.run(vazia)
  end
end
