defmodule OGrupoDeEstudos.Media.ObjectStorageTest do
  @moduledoc """
  A porta de bytes: guarda, serve e apaga objetos por chave opaca.

  É a ÚNICA camada que sabe onde os bytes moram. Quando o storage sair do
  volume do Fly para um provider externo, é só um adapter novo aqui: nomes,
  Mogrify e permissão não mudam de lugar.
  """

  # async: false — troca :uploads_path e o adapter, que são config global.
  use ExUnit.Case, async: false

  import Mox

  alias OGrupoDeEstudos.Media.ObjectStorage
  alias OGrupoDeEstudos.Media.ObjectStorage.LocalDisk

  setup do
    dir = Path.join(System.tmp_dir!(), "object_storage_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    anterior = Application.get_env(:o_grupo_de_estudos, :uploads_path)
    Application.put_env(:o_grupo_de_estudos, :uploads_path, dir)

    on_exit(fn ->
      case anterior do
        nil -> Application.delete_env(:o_grupo_de_estudos, :uploads_path)
        valor -> Application.put_env(:o_grupo_de_estudos, :uploads_path, valor)
      end

      File.rm_rf!(dir)
    end)

    origem = Path.join(dir, "origem.bin")
    File.write!(origem, "conteudo de teste")

    %{dir: dir, origem: origem}
  end

  describe "LocalDisk.put/2" do
    test "grava os bytes na chave, criando as pastas do caminho", ctx do
      assert :ok = LocalDisk.put("avatars/u1_99.jpg", ctx.origem)

      assert File.read!(Path.join(ctx.dir, "avatars/u1_99.jpg")) == "conteudo de teste"
    end

    test "origem que não existe devolve erro em vez de estourar", _ctx do
      assert {:error, _motivo} = LocalDisk.put("avatars/x.jpg", "/nao/existe.bin")
    end
  end

  describe "LocalDisk.delete/1" do
    test "apaga o objeto", ctx do
      :ok = LocalDisk.put("flyers/a.jpg", ctx.origem)

      assert :ok = LocalDisk.delete("flyers/a.jpg")
      refute File.exists?(Path.join(ctx.dir, "flyers/a.jpg"))
    end

    test "apagar o que já não existe é silencioso", _ctx do
      assert :ok = LocalDisk.delete("flyers/sumiu.jpg")
    end
  end

  describe "LocalDisk.exists?/1 e list/1" do
    test "enxerga o que guardou", ctx do
      :ok = LocalDisk.put("avatars/u1_1.jpg", ctx.origem)
      :ok = LocalDisk.put("avatars/u1_2.jpg", ctx.origem)
      :ok = LocalDisk.put("avatars/u2_1.jpg", ctx.origem)

      assert LocalDisk.exists?("avatars/u1_1.jpg")
      refute LocalDisk.exists?("avatars/u9_9.jpg")

      assert Enum.sort(LocalDisk.list("avatars/u1_")) == ["avatars/u1_1.jpg", "avatars/u1_2.jpg"]
      assert LocalDisk.list("workshop_media/") == []
    end

    test "list desce em subpastas e devolve só arquivos, como um bucket", ctx do
      # Chave é caminho plano no contrato: pasta não é objeto. Sem isso o
      # adapter de disco divergiria do R2 quando as chaves têm subpastas.
      :ok = LocalDisk.put("workshop_media/w1/a.mp4", ctx.origem)
      :ok = LocalDisk.put("workshop_media/w2/b.mp4", ctx.origem)

      assert Enum.sort(LocalDisk.list("workshop_media/")) ==
               ["workshop_media/w1/a.mp4", "workshop_media/w2/b.mp4"]

      assert LocalDisk.list("workshop_media/w1/") == ["workshop_media/w1/a.mp4"]
    end
  end

  describe "LocalDisk.public_url/1" do
    test "a URL pública é o caminho servido pelo UploadsStatic" do
      assert LocalDisk.public_url("avatars/u1.jpg") == "/uploads/avatars/u1.jpg"
    end
  end

  describe "LocalDisk.serve/1" do
    test "objeto local se serve por arquivo, para o send_file do controller", ctx do
      :ok = LocalDisk.put("workshop_media/v.mp4", ctx.origem)

      assert {:file, caminho} = LocalDisk.serve("workshop_media/v.mp4")
      assert File.read!(caminho) == "conteudo de teste"
    end

    test "chave sem objeto devolve not_found", _ctx do
      assert {:error, :not_found} = LocalDisk.serve("workshop_media/fantasma.mp4")
    end
  end

  describe "LocalDisk.with_local_file/2" do
    test "entrega um caminho legível para quem processa (ffmpeg, Mogrify)", ctx do
      :ok = LocalDisk.put("workshop_media/v.mov", ctx.origem)

      assert {:ok, "CONTEUDO DE TESTE"} =
               LocalDisk.with_local_file("workshop_media/v.mov", fn caminho ->
                 caminho |> File.read!() |> String.upcase()
               end)
    end

    test "chave sem objeto devolve not_found sem rodar a função", _ctx do
      assert {:error, :not_found} =
               LocalDisk.with_local_file("workshop_media/nada.mov", fn _ ->
                 flunk("não era para rodar")
               end)
    end
  end

  describe "LocalDisk.free_bytes/0" do
    test "mede o espaço do volume dos uploads", _ctx do
      assert is_integer(LocalDisk.free_bytes()) and LocalDisk.free_bytes() > 0
    end
  end

  describe "fachada: o domínio fala com o adapter configurado" do
    setup :verify_on_exit!

    setup do
      Application.put_env(:o_grupo_de_estudos, ObjectStorage, adapter: ObjectStorage.Mock)
      on_exit(fn -> Application.delete_env(:o_grupo_de_estudos, ObjectStorage) end)
      :ok
    end

    test "put e serve passam pelo adapter, com o retorno intacto" do
      expect(ObjectStorage.Mock, :put, fn "k/a.bin", "/tmp/a" -> :ok end)
      expect(ObjectStorage.Mock, :serve, fn "k/a.bin" -> {:redirect, "https://cdn/a.bin"} end)

      assert ObjectStorage.put("k/a.bin", "/tmp/a") == :ok
      assert ObjectStorage.serve("k/a.bin") == {:redirect, "https://cdn/a.bin"}
    end

    test "sem configuração nenhuma, o padrão é o disco local" do
      Application.delete_env(:o_grupo_de_estudos, ObjectStorage)

      assert ObjectStorage.public_url("x/y.png") == "/uploads/x/y.png"
    end
  end
end
